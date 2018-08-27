//
//  ConversationTableViewController.swift
//  CloudMessage2
//
//  Created by Tyler Gee on 8/4/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class ConversationTableViewController: UITableViewController {
    
    // MARK: - Properties
    
    var conversations: [Conversation] = [Conversation]()
    var selectedIndexPath: IndexPath? // Necessary because we deselect the row right after it is selected (otherwise it looks ugly)
    
    var cloudController: CloudController!
    var coreDataController: CoreDataController!
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateWithCoreData()
        updateWithCloud()
        
        tableView.rowHeight = 60
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        registerAsNotificationDelegate()
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Add Conversation
        if let destinationViewController = segue.destination.childViewControllers.first as? AddConversationTableViewController, segue.identifier == "AddConversation" {
            destinationViewController.delegate = self
            destinationViewController.coreDataController = coreDataController
            destinationViewController.cloudController = cloudController
        } else if let destinationViewController = segue.destination as? MessageTableViewController, segue.identifier == "MessageTableView" {
            
            // (didSelectRowAtIndexPath is actually called after prepare(for:)
            guard let indexPathForSelectedRow = tableView.indexPathForSelectedRow else { return }
            selectedIndexPath = indexPathForSelectedRow
            
            // Dependency injection of conversation
            let selectedConversation = conversations[indexPathForSelectedRow.row]
            destinationViewController.conversation = selectedConversation
            
            // Dependency injection of cloud controller
            destinationViewController.cloudController = cloudController
            destinationViewController.coreDataController = coreDataController
            
            // Set up delegate
            destinationViewController.delegate = self
            
            // Set the title
            destinationViewController.navigationItem.title = selectedConversation.title
        }
    }
}

// MARK: - Helper Methods

extension ConversationTableViewController {
    
    func updateWithCloud(completion: @escaping (Bool) -> Void = { (didFetchRecords) in }) {
        var didFetchRecords: Bool = false
        
        let zonesDeleted: ([CKRecordZoneID]) -> Void = { (zoneIDs) in
            if zoneIDs.count > 0 {
                didFetchRecords = true
                
                // TODO: Implement this later (when you add zones), for now it will just delete everything
                for conversation in self.conversations {
                    self.coreDataController.delete(conversation)
                }
                self.coreDataController.save()
                
                self.conversations = []
            }
        }
        
        let saveChanges: ([CKRecord], [CKRecordID]) -> Void = { (recordsChanged, recordIDsDeleted) in
            for record in recordsChanged {
                didFetchRecords = true
                
                if let index = self.conversations.index(where: { $0.ckRecord.recordID == record.recordID }) {
                    print("Modified conversation from ConversationTableViewController (from Cloud)")
                    
                    let oldDateLastModified = self.conversations[index].dateLastModified
                    
                    self.conversations[index].update(withRecord: record)
                    let changedIndexPath = IndexPath(row: index, section: 0)
                    
                    let newDateLastModified = self.conversations[index].dateLastModified
                    
                    self.conversations.sort(by: { $0.dateLastModified > $1.dateLastModified })
                    
                    DispatchQueue.main.sync {
                        self.coreDataController.save()
                        
                        self.tableView.beginUpdates()
                        self.tableView.reloadRows(at: [changedIndexPath], with: .automatic)
                        self.tableView.endUpdates()
                        
                        if newDateLastModified > oldDateLastModified {
                            self.tableView.beginUpdates()
                            self.tableView.moveRow(at: changedIndexPath, to: IndexPath(row: 0, section: 0))
                            self.tableView.endUpdates()
                        }
                    }
                } else if record.recordType == "Conversation" {
                    print("Added conversation from ConversationTableViewController (from Cloud)")
                    
                    self.conversations.append(Conversation(fromRecord: record, managedContext: self.coreDataController.managedContext))
                    let newIndexPath = IndexPath(row: 0, section: 0)
                    self.conversations.sort(by: { $0.dateLastModified > $1.dateLastModified })
                    
                    DispatchQueue.main.sync {
                        self.coreDataController.save()
                        
                        self.tableView.beginUpdates()
                        self.tableView.insertRows(at: [newIndexPath], with: .automatic)
                        self.tableView.endUpdates()
                    }
                } else if record.recordType == "Message" {
                    print("Added message from ConversationTableViewController (from Cloud)")
                    
                    guard let index = self.conversations.index(where: { record["owningConversation"] as? CKReference == CKReference(record: $0.ckRecord, action: .none) })
                        else { return }
                    
                    if let messageIndex = self.conversations[index].messages.index(where: { $0.ckRecord.recordID == record.recordID }) {
                        self.conversations[index].messages[messageIndex].update(withRecord: record)
                    } else {
                        self.conversations[index].coreDataConversation.addToMessages(Message(fromRecord: record, managedContext: self.coreDataController.managedContext).coreDataMessage)
                    }
                    
                    DispatchQueue.main.sync {
                        self.coreDataController.save()
                        
                        self.tableView.beginUpdates()
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                        self.tableView.endUpdates()
                    }
                }
            }
            
            for recordID in recordIDsDeleted {
                didFetchRecords = true
                
                if let index = self.conversations.index(where: { $0.ckRecord.recordID == recordID }) {
                    print("Conversation deleted by ConversationTableViewController (from Cloud)")
                    
                    self.coreDataController.delete(self.conversations.remove(at: index))
                    
                    DispatchQueue.main.sync {
                        self.tableView.beginUpdates()
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
                        self.tableView.endUpdates()
                        
                        self.coreDataController.save()
                    }
                } else {
                    var affectedIndexes: [Int] = []
                    
                    for (conversationIndex, conversation) in self.conversations.enumerated() {
                        if let index = conversation.messages.index(where: { $0.ckRecord.recordID == recordID }) {
                            print("Message deleted by ConversationTableViewController (from Cloud)")
                            
                            let deletedMessage = conversation.messages[index]
                            self.coreDataController.delete(deletedMessage)
                            conversation.coreDataConversation.removeFromMessages(deletedMessage.coreDataMessage)
                            
                            affectedIndexes.append(conversationIndex)
                        }
                    }
                    
                    DispatchQueue.main.sync {
                        self.coreDataController.save()
                        
                        self.tableView.beginUpdates()
                        self.tableView.reloadRows(at: affectedIndexes.map({ IndexPath(row: $0, section: 0)}), with: .automatic)
                        self.tableView.endUpdates()
                    }
                }
            }
        }
        
        cloudController.fetchDatabaseChanges(zonesDeleted: zonesDeleted, saveChanges: saveChanges) {
            completion(didFetchRecords)
        }
    }
    
    func updateWithCoreData() {
        // Initialize Conversations:
        // Get from Core Data
        coreDataController.fetchConversations() { (coreDataConversations) in
            for coreDataConversation in coreDataConversations {
                self.conversations.append(Conversation(fromCoreDataConversation: coreDataConversation, zoneID: self.cloudController.zoneID))
            }
            self.conversations.sort() { $0.dateLastModified > $1.dateLastModified }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    func registerAsNotificationDelegate() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.notificationDelegate = self
        
        print("Conversation Table View Controller registered as the notification delegate")
    }
}





// MARK: - Table View Data Source / Delegate

extension ConversationTableViewController {
    
    // MARK: - Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath)
        
        // Get model object
        let conversation = conversations[indexPath.row]
        
        // Configure cell with model
        cell.textLabel?.text = conversation.title
        cell.detailTextLabel?.text = conversation.latestMessage
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let deletedConversation = conversations.remove(at: indexPath.row)
            
            // Delete all cloud messages
            for message in deletedConversation.messages {
                coreDataController.delete(message)
            }
            
            // Delete from cloud
            cloudController.delete([deletedConversation]) {
                print("Deleted Conversation!")
            }
            
            // Delete from core data
            coreDataController.delete(deletedConversation)
            
            // Update View
            
            self.tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableView.endUpdates()
        }
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
        
        selectedIndexPath = indexPath
    }
}

// MARK: - Notification Delegate

extension ConversationTableViewController: NotificationDelegate {
    func fetchChanges(completion: @escaping (Bool) -> Void) {
        self.updateWithCloud { (didFetchRecords) in
            completion(didFetchRecords)
        }
    }
}





// MARK: - Add Conversation Delegate

extension ConversationTableViewController: AddConversationTableViewControllerDelegate {
    func addedConversation(_ conversation: Conversation) {
        print("Conversation added by ConversationTableViewController")
        
        // Save change to the Cloud
        cloudController.save([conversation]) { }
        
        // Save change to Core Data
        coreDataController.save()
        
        conversations.append(conversation)
        conversations.sort { $0.dateLastModified > $1.dateLastModified }
        
        self.tableView.beginUpdates()
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
        self.tableView.endUpdates()
    }
}




// MARK: - Message Table View Delegate

extension ConversationTableViewController: MessageTableViewControllerDelegate {
    func conversationDidChange(to conversation: Conversation, wasModified: Bool) {
        print("Conversation changed by MessageTableViewController")
        
        // Save change to Core Data
        coreDataController.save()
        
        if wasModified {
            // Save change to the cloud
            cloudController.save([conversation]) { }
            
            conversation.coreDataConversation.dateLastModified = NSDate()
        }
        
        conversations.sort(by: { $0.dateLastModified > $1.dateLastModified })
        
        if let selectedIndexPath = selectedIndexPath, selectedIndexPath.row < conversations.count {
            conversations[selectedIndexPath.row] = conversation
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [selectedIndexPath], with: .automatic)
            }
        }
    }
}
