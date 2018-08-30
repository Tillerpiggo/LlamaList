//
//  MessageTableViewController.swift
//  CloudMessage2
//
//  Created by Tyler Gee on 8/4/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

protocol MessageTableViewControllerDelegate {
    func conversationDidChange(to conversation: Conversation, wasModified: Bool, saveToCloud: Bool)
}

class MessageTableViewController: UITableViewController {
    
    // MARK: - Properties
    var conversation: Conversation!
    var delegate: MessageTableViewControllerDelegate?
    
    var cloudController: CloudController!
    var coreDataController: CoreDataController!
    
    lazy var fetchedResultsController: NSFetchedResultsController<CoreDataMessage> = {
        let fetchRequest: NSFetchRequest<CoreDataMessage> = CoreDataMessage.fetchRequest()
        let sortByDateLastModified = NSSortDescriptor(key: #keyPath(CoreDataConversation.dateLastModified), ascending: false)
        fetchRequest.sortDescriptors = [sortByDateLastModified]
        fetchRequest.fetchBatchSize = 20
        
        let fetchedResultsController = NSFetchedResultsController (
            fetchRequest: fetchRequest,
            managedObjectContext: coreDataController.managedContext,
            sectionNameKeyPath: nil,
            cacheName: "CloudMessage"
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Fetching error: \(error), \(error.userInfo)")
        }
        
        return fetchedResultsController
    }()
    
    // MARK: - Initializer
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Multiple lines per message
        tableView.rowHeight = UITableViewAutomaticDimension
        
        // Core Data will already fetch messages until we optimize it not to
        // TODO: Optimize core data by only fetching and editing the title/dateModified of the conversation, loading/fetching messages later
        
        updateWithCloud()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        registerAsNotificationDelegate()
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController,
            let destinationViewController = navigationController.topViewController as? AddMessageTableViewController,
            segue.identifier == "AddMessage" else { return }
        
        destinationViewController.delegate = self
        destinationViewController.coreDataController = coreDataController
        destinationViewController.cloudController = cloudController
        destinationViewController.owningConversation = CKReference(record: conversation.ckRecord, action: .none)
    }
}

// MARK: - Table View Data Source / Delegate

extension MessageTableViewController {
    
    // MARK: - Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfRowsInSection = conversation.messages.count
        
        return numberOfRowsInSection
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath)
        
        print("Loading cell at row \(indexPath.row)")
        
        // Get model object
        let message = conversation.messages[indexPath.row]
        
        // Configure cell
        cell.textLabel?.text = message.text
        cell.detailTextLabel?.text = message.formattedTimestamp
        
        return cell
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
    }
}

// MARK: - Helper Methods

extension MessageTableViewController {
    func updateWithCloud(completion: @escaping (Bool) -> Void = { (didFetchRecords) in }) {
        var didFetchRecords: Bool = false
        
        let zonesDeleted: ([CKRecordZoneID]) -> Void = { (zoneIDs) in
            if zoneIDs.count > 0 {
                didFetchRecords = true
                
                self.coreDataController.delete(self.conversation)
                
                // TODO: Implement this later (when you add zones), for now it will just delete everything
                for message in self.conversation.messages {
                    self.coreDataController.delete(message)
                }
                self.coreDataController.save()
            }
        }
        
        let saveChanges: ([CKRecord], [CKRecordID]) -> Void = { (recordsChanged, recordIDsDeleted) in
            for record in recordsChanged {
                if let index = self.conversation.messages.index(where: { $0.ckRecord.recordID == record.recordID }) {
                    didFetchRecords = true
                    
                    print("Fetched message: \(self.conversation.messages[index].text)")
                    
                    print("Message edited by MessageTableViewController (from Cloud)")
                    
                    self.conversation.messages[index].update(withRecord: record)
                    
                    let changedIndexPath = IndexPath(row: index, section: 0)
                    
                    self.coreDataController.save()
                    
                    DispatchQueue.main.async {
                        self.tableView.beginUpdates()
                        self.tableView.reloadRows(at: [changedIndexPath], with: .automatic)
                        self.tableView.beginUpdates()
                    }
                } else if record.recordType == "Message" && record["owningConversation"] as? CKReference == CKReference(record: self.conversation.ckRecord, action: .none) {
                    didFetchRecords = true
                    
                    print("Message added by MessageTableViewController (from Cloud)")
                    
                    self.conversation.coreDataConversation.addToMessages(Message(fromRecord: record, managedContext: self.coreDataController.managedContext).coreDataMessage)
                    let newIndexPath = IndexPath(row: 0, section: 0)
                    
                    self.coreDataController.save()
                    
                    DispatchQueue.main.async {
                        self.tableView.beginUpdates()
                        self.tableView.insertRows(at: [newIndexPath], with: .automatic)
                        print("Inserted row in messageTableViewController!")
                        self.tableView.endUpdates()
                    }
                }
            }
            
            for recordID in recordIDsDeleted {
                print("Message deleted by MessageTableViewController (from Cloud)")
                
                if let index = self.conversation.messages.index(where: { $0.ckRecord.recordID == recordID }) {
                    didFetchRecords = true
                    
                    let message = self.conversation.messages[index]
                    self.conversation.coreDataConversation.removeFromMessages(message.coreDataMessage)
                    
                    self.coreDataController.save()
                    
                    DispatchQueue.main.async {
                        self.tableView.beginUpdates()
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                        print("Deleted row in messageTableViewController!")
                        self.tableView.endUpdates()
                    }
                 } else if recordID == self.conversation.ckRecord.recordID {
                    didFetchRecords = true
                    
                    self.coreDataController.delete(self.conversation)
                    
                    for message in self.conversation.messages {
                        self.coreDataController.delete(message)
                    }
                    
                    self.coreDataController.save()
                    
                    DispatchQueue.main.async {
                        self.navigationController?.popViewController(animated: true)
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
        
        cloudController.fetchDatabaseChanges(zonesDeleted: zonesDeleted, saveChanges: saveChanges) {
            self.delegate?.conversationDidChange(to: self.conversation, wasModified: didFetchRecords, saveToCloud: false)
            completion(didFetchRecords)
        }
    }
    
    func registerAsNotificationDelegate() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.notificationDelegate = self
        
        print("Message Table View Controller registered as the notification delegate")
    }
}

// MARK: - Notification Delegate

extension MessageTableViewController: NotificationDelegate {
    func fetchChanges(completion: @escaping (Bool) -> Void) {
        self.updateWithCloud { (didFetchRecords) in
            completion(didFetchRecords)
        }
    }
}

// MARK: - Add Message Delegate

extension MessageTableViewController: AddMessageTableViewControllerDelegate {
    func addedMessage(_ message: Message) {
        print("Message added by MessageTableViewController (from user input)")
        
        // Modify model
        conversation.coreDataConversation.addToMessages(message.coreDataMessage)
        conversation.ckRecord["latestMessage"] = message.text as CKRecordValue
        
        // Notify delegate
        delegate?.conversationDidChange(to: conversation, wasModified: true, saveToCloud: true)
        
        // Save to Core Data
        coreDataController.save()
        
        print("After adding a message, the conversation had \(conversation.messages.count) messages before saving.")
        
        // Modify table view
        tableView.beginUpdates()
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
        tableView.endUpdates()
        
        // Save to the Cloud
        cloudController.save([message], recordChanged: { (updatedRecord) in
            message.update(withRecord: updatedRecord)
        })
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ConversationTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic)
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
