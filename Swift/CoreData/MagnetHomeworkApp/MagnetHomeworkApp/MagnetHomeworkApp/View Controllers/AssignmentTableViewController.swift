//
//  AddAssignmentTableViewController.swift
//  MagnetHomeworkApp
//
//  Created by Tyler Gee on 10/30/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

protocol AssignmentTableViewControllerDelegate {
    func reloadClass(_ `class`: Class)
}

class AssignmentTableViewController: UITableViewController {
    
    // MARK: - Properties
    
    var `class`: Class!
    
    var cloudController: CloudController!
    var coreDataController: CoreDataController!
    
    var delegate: AssignmentTableViewControllerDelegate?
    
    var selectedAssignment: Assignment?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController<Assignment> = {
        let fetchRequest: NSFetchRequest<Assignment> = Assignment.fetchRequest()
        let sortBySectionNumber = NSSortDescriptor(key: #keyPath(Assignment.dueDateSectionNumber), ascending: true)
        let sortByDueDate = NSSortDescriptor(key: #keyPath(Assignment.dueDate), ascending: true)
        let sortByCreationDate = NSSortDescriptor(key: #keyPath(Assignment.creationDate), ascending: true)
        fetchRequest.sortDescriptors = [sortBySectionNumber, sortByDueDate, sortByCreationDate]
        fetchRequest.fetchBatchSize = 20 // TODO: May need to adjust
        
        let isInClassPredicate = NSPredicate(format: "owningClass == %@", self.`class`)
        fetchRequest.predicate = isInClassPredicate
        
        let fetchedResultsController = NSFetchedResultsController (
            fetchRequest: fetchRequest,
            managedObjectContext: coreDataController.managedContext,
            sectionNameKeyPath: #keyPath(Assignment.dueDateSection),
            cacheName: "\(self.`class`.ckRecord.recordID.recordName)"
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Fetching error: \(error), \(error.userInfo)")
        }
        
        return fetchedResultsController
    }()
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var addAssignmentView: UIView!
    @IBOutlet weak var addAssignmentContainerView: UIView!
    @IBOutlet weak var addAssignmentButton: UIButton!
    @IBOutlet weak var addAssignmentTextField: UITextField!
    @IBOutlet weak var addAssignmentText: UILabel!
    
    // MARK: - IBActions
    
    @IBAction func shareButtonTapped(_ sender: UIBarButtonItem) {
        // Create a share for the class
        let classShare = CKShare(rootRecord: `class`.ckRecord)
        
        classShare[CKShare.SystemFieldKey.title] = "Share the class: \(`class`.name as CKRecordValue? ?? "[Untitled]" as CKRecordValue)"
        classShare[CKShare.SystemFieldKey.shareType] = "Class" as CKRecordValue?
        
        // Create a UIShareController to give the user a UI for sharing
        let sharingController = UICloudSharingController(preparationHandler: { (controller, handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
            self.cloudController.save([self.`class`.ckRecord, classShare], inDatabase: .private, recordChanged: { (record) in }) { (error) in
                handler(classShare, CKContainer.default(), error)
            }
        })
        
        sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]
        sharingController.delegate = self
        
        present(sharingController, animated: true, completion: nil)
    }
    
    // MARK: - Initializer
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureAddAssignmentView(duration: 0)
        updateHeaderView()
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController,
            let destinationViewController = navigationController.topViewController as? ScheduleTableViewController,
            let selectedAssignment = self.selectedAssignment,
            segue.identifier == "ScheduleTableView" else { return }
        
        destinationViewController.assignment = selectedAssignment
        destinationViewController.coreDataController = coreDataController
        destinationViewController.delegate = self
    }
}

// MARK: - Table View Data Source / Delegate

extension AssignmentTableViewController {
    
    // MARK: - Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = fetchedResultsController.sections else {
            return 0
        }
        
        return sections.count // TODO: optimize to just get number of sections without having to load them
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionInfo = fetchedResultsController.sections?[section] else {
            return 0
        }
        
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "AssignmentCell", for: indexPath) as! AssignmentTableViewCell
        
        // Get model object
        let assignment = fetchedResultsController.object(at: indexPath)
        
        // Configure cell
        cell.configure(withAssignment: assignment)
        cell.delegate = self
        //cell.separatorView.isHidden = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        cell.separatorView.isHidden = true
        if tableView.numberOfRows(inSection: indexPath.section) == 1 {
            //cell.addDropShadow(color: .black, opacity: 0.07, radius: 5, yOffset: -10)
        } else if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
            //cell.separatorView.isHidden = true
            //cell.addDropShadow(color: .black, opacity: 0.07, radius: 3, yOffset: 12)
        } else if indexPath.row == 0 {
            //cell.addDropShadow(color: .black, opacity: 0.07, radius: 5, yOffset: -10)
        } else {
            cell.separatorView.isHidden = true
            cell.subviews.first?.removeDropShadow()
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionInfo = fetchedResultsController.sections?[section]
        return sectionInfo?.name
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let assignment = fetchedResultsController.object(at: indexPath)

        if let dueDate = assignment.dueDate as Date?, dueDate != Date.tomorrow {
            return 60
        } else {
            return 44
        }
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let scheduleRowAction = UITableViewRowAction(style: .default, title: "Schedule", handler: { (action, indexpath) in
            self.selectedAssignment = self.fetchedResultsController.object(at: indexPath)
            self.performSegue(withIdentifier: "ScheduleTableView", sender: self)
        })
        scheduleRowAction.backgroundColor = .scheduleColor
        
        let deleteRowAction = UITableViewRowAction(style: .default, title: "Delete", handler: { (action, indexPath) in
            let deletedAssignment = self.fetchedResultsController.object(at: indexPath)
            
            if self.fetchedResultsController.fetchedObjects?.count == 1 {
                var frame = CGRect.zero
                frame.size.height = 20
                tableView.tableHeaderView = UIView(frame: frame)
                
//                UIView.animate(withDuration: 0.0, animations: {
//                }, completion: { (bool) in
//                    UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseInOut], animations: {
//                        tableView.tableHeaderView = UIView(frame:frame)
//                    })
//                })
            }
            
            // Delete from core data
            self.coreDataController.delete(deletedAssignment)
            self.coreDataController.save()
            
            // Delete from cloud
            self.cloudController.delete([deletedAssignment], inDatabase: .private) {
                print("Deleted Class!")
            }
        })
        deleteRowAction.backgroundColor = .deleteColor

        return [deleteRowAction, scheduleRowAction]
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
    }
}

// MARK: - Add Assignment Delegate

extension AssignmentTableViewController: AddAssignmentTableViewControllerDelegate {
    func addedAssignment(_ assignment: Assignment) {
        print("Assignment added by AssignmentTableViewController (from user input)")
        
        // Modify model
        `class`.addToAssignments(assignment)
        assignment.owningClass = `class`
        `class`.ckRecord["latestAssignment"] = assignment.text as CKRecordValue?
        `class`.dateLastModified = NSDate()
        
        // Save to Core Data
        coreDataController.save()
        
        delegate?.reloadClass(`class`)
        
        let databaseType: DatabaseType = `class`.isUserCreated ? .private : .shared
        
        print("ClassNameToSave: \(self.`class`.ckRecord["name"] as String?)")
        
        if databaseType == .private {
            // Save to the Cloud
            cloudController.save([assignment, assignment.toDo!, self.`class`], inDatabase: databaseType, recordChanged: { (updatedRecord) in
                if updatedRecord.recordType == "Assignment" {
                    assignment.update(withRecord: updatedRecord)
                } else if updatedRecord.recordType == "ToDo" {
                    assignment.toDo?.update(withRecord: updatedRecord)
                } else {
                    self.`class`.update(withRecord: updatedRecord)
                }
            }) { (error) in
                guard let error = error as? CKError else { return }
                switch error.code {
                case .requestRateLimited, .zoneBusy, .serviceUnavailable:
                    break
                default:
                    DispatchQueue.main.async {
                        self.alertUserOfFailure()
                        self.coreDataController.save()
                    }
                }
            }
        } else {
            // Save to the Cloud
            cloudController.save([assignment.toDo!], inDatabase: .private, recordChanged: { (updatedRecord) in
                assignment.toDo?.update(withRecord: updatedRecord)
            }) { (error) in
                guard let error = error as? CKError else { return }
                switch error.code {
                case .requestRateLimited, .zoneBusy, .serviceUnavailable:
                    break
                default:
                    DispatchQueue.main.async {
                        self.alertUserOfFailure()
                        self.coreDataController.save()
                    }
                }
            }
            
            // Save to the Cloud
            cloudController.save([assignment, self.`class`], inDatabase: databaseType, recordChanged: { (updatedRecord) in
                if updatedRecord.recordType == "Assignment" {
                    assignment.update(withRecord: updatedRecord)
                } else if updatedRecord.recordType == "ToDo" {
                    assignment.toDo?.update(withRecord: updatedRecord)
                } else {
                    self.`class`.update(withRecord: updatedRecord)
                }
            }) { (error) in
                guard let error = error as? CKError else { return }
                switch error.code {
                case .requestRateLimited, .zoneBusy, .serviceUnavailable:
                    break
                default:
                    DispatchQueue.main.async {
                        self.alertUserOfFailure()
                        self.coreDataController.save()
                    }
                }
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension AssignmentTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic)
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView.insertSections([sectionIndex], with: .fade)
        case .delete:
            self.tableView.deleteSections([sectionIndex], with: .fade)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

// MARK: - UICloudSharingControllerDelegate

extension AssignmentTableViewController: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        // TODO: Show the user that the operation failed, handle the error
        print("Cloud sharing error: \(error)")
    }
    
    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        // Set the image
        if let thumbnail = UIImage(named: "magnetHomeworkApThumbnail") { // TODO: Add an image to the project
            return thumbnail.pngData()
        } else {
            return nil
        }
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        // Set the title here
        return `class`.name ?? "Untitled Class"
    }
}

// MARK: - Helper Methods

extension AssignmentTableViewController {
    func alertUserOfFailure() {
        let alertController = UIAlertController(title: "Something went wrong!", message: "Check you connection and make sure you have the proper permissions to perform the desired action.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func updateHeaderView() {
        if tableView.numberOfRows(inSection: 0) == 0 {
            var frame = CGRect.zero
            frame.size.height = 20
            tableView.tableHeaderView = UIView(frame: frame)
        } else {
            var frame = CGRect.zero
            frame.size.height = 20
            tableView.tableHeaderView = UIView(frame: frame)
        }
    }
}

// MARK: - ClassTableViewControllerDelegate

extension AssignmentTableViewController: ClassTableViewControllerDelegate {
    func classDeleted() {
        self.navigationController?.popViewController(animated: true)
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - AssignmentTableViewCellDelegate

extension AssignmentTableViewController: AssignmentTableViewCellDelegate {
    func buttonPressed(assignment: Assignment) -> Bool {
        if let assignment = fetchedResultsController.fetchedObjects?.first(where: { $0 == assignment }), let toDo = assignment.toDo {
            toDo.isCompleted = !toDo.isCompleted
            toDo.ckRecord["isCompleted"] = toDo.isCompleted as CKRecordValue?
            
            cloudController.save([toDo], inDatabase: .private, recordChanged: { (updatedRecord) in
                assignment.toDo?.update(withRecord: updatedRecord)
            }) { (error) in
                guard let error = error as? CKError else { return }
                switch error.code {
                case .requestRateLimited, .zoneBusy, .serviceUnavailable:
                    break
                default:
                    print("ERROR: \(error.code)")
                    DispatchQueue.main.async {
                        self.alertUserOfFailure()
                        self.coreDataController.save()
                    }
                }
            }
            
            return toDo.isCompleted
        } else {
            print("Couldn't find associated assignment; look at AssignmentTableViewController: AssignmentTableViewCellDelegate")
            return true
        }
    }
}

// MARK: - ScheduleTableViewControllerDelegate

extension AssignmentTableViewController: ScheduleTableViewControllerDelegate {
    func reloadAssignment(_ assignment: Assignment) {
        if let indexPath = fetchedResultsController.indexPath(forObject: assignment) {
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        DispatchQueue.main.async { self.coreDataController.save() }
        
        let databaseType: DatabaseType = `class`.isUserCreated ? .private : .shared
        cloudController.save([assignment], inDatabase: databaseType, recordChanged: { (updatedRecord) in
            assignment.update(withRecord: updatedRecord)
        }) { (error) in
            guard let error = error as? CKError else { return }
            switch error.code {
            case .requestRateLimited, .zoneBusy, .serviceUnavailable:
                break
            default:
                DispatchQueue.main.async {
                    self.alertUserOfFailure()
                    self.coreDataController.save()
                }
            }
        }
    }
}

// MARK: - AddAssignmentView

extension AssignmentTableViewController: UITextFieldDelegate, UITextDragDelegate {
    
    @IBAction func addAssignmentButtonPressed(_ sender: Any) {
        addAssignmentButton.isHidden = true
        UIView.animate(withDuration: 0.1, animations: {
            self.addAssignmentView.backgroundColor = .white
        })
        
        addAssignmentText.isHidden = true
        addAssignmentTextField.isHidden = false
        
        addAssignmentTextField.becomeFirstResponder()
        addDoneButton()
    }
    
    @IBAction func addAssignmentButtonPressedDown(_ sender: Any) {
        UIView.animate(withDuration: 0.1, animations: {
            self.addAssignmentView.backgroundColor = UIColor.highlightColor
        })
    }
    
    @IBAction func addAssignmentButtonDraggedOutside(_ sender: Any) {
        UIView.animate(withDuration: 0.1, animations: {
            self.addAssignmentView.backgroundColor = UIColor.primaryColor
        })
    }
    
    @IBAction func addAssignmentButtonTouchCanceled(_ sender: Any) {
        configureAddAssignmentView(duration: 0.1)
    }
    
    @IBAction func addAssignmentButtonDraggedInside(_ sender: Any) {
        UIView.animate(withDuration: 0.1, animations: {
            self.addAssignmentView.backgroundColor = UIColor.highlightColor
        })
    }
    
    @IBAction func addAssignmentButtonDragExited(_ sender: Any) {
        configureAddAssignmentView(duration: 0.1)
    }
    
    func configureAddAssignmentView(duration: TimeInterval) {
        addAssignmentView.layer.cornerRadius = 5
        addAssignmentView.addDropShadow(color: .black, opacity: 0.15, radius: 4)
        addAssignmentTextField.text = ""
        
        self.addAssignmentTextField.isHidden = true
        self.addAssignmentText.isHidden = false
        
        UIView.animate(withDuration: duration, animations: {
            self.addAssignmentView.backgroundColor = UIColor.primaryColor
            
            if self.navigationItem.rightBarButtonItems?.count ?? 0 > 1 {
                self.navigationItem.rightBarButtonItem = nil
            }
        }, completion: { (bool) in
            self.addAssignmentButton.isHidden = false
        })
    }
    
    func addDoneButton() {
        self.navigationItem.setRightBarButtonItems([UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(AssignmentTableViewController.donePressed(sender:))), self.navigationItem.rightBarButtonItem!], animated: true)
    }
    
    @objc func donePressed(sender: UIBarButtonItem) {
        addAssignmentTextField.resignFirstResponder()
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if let text = addAssignmentTextField.text, text != "" {
            saveAssignment(text: text)
        }
        
        configureAddAssignmentView(duration: 0.2)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        addAssignmentTextField.resignFirstResponder()
        return true
    }
    
    private func saveAssignment(text: String) {
        // Create new assignment
        let zoneID = `class`.ckRecord.recordID.zoneID
        let newAssignment = Assignment(withText: text, managedContext: coreDataController.managedContext, owningClass: `class`, zoneID: zoneID, toDoZoneID: cloudController.zoneID)
        addedAssignment(newAssignment)
        
        updateHeaderView()
    }
}
