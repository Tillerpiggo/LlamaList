//
//  ToDoTableViewController.swift
//  MagnetHomeworkApp
//
//  Created by Tyler Gee on 11/13/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class ToDoTableViewController: AddObjectViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var cloudController: CloudController!
    var coreDataController: CoreDataController!
    
    var selectedAssignment: Assignment?
    
    var showsCompleted: Bool = false
    var isCompletedHidden: Bool = true
    
    var hiddenSections: [Int] = []
    
    func predicate() -> NSPredicate {
        return NSPredicate(value: true)
        return NSPredicate(format: "dueDate >= %@", Date.tomorrow as CVarArg)
    }
    
    func cacheName() -> String {
        return "ToDo"
    }
    
    var sortDescriptors: [NSSortDescriptor] = {
        let sortBySectionNumber = NSSortDescriptor(key: #keyPath(Assignment.dueDateSectionNumber), ascending: true)
        let sortByDueDate = NSSortDescriptor(key: #keyPath(Assignment.dueDate), ascending: true)
        let sortByCreationDate = NSSortDescriptor(key: #keyPath(Assignment.creationDate), ascending: true)
        let sortByCompletionDate = NSSortDescriptor(key: #keyPath(Assignment.toDo.completionDate), ascending: false)
        
        return [sortBySectionNumber, sortByCompletionDate, sortByDueDate, sortByCreationDate]
    }()
    
    lazy var fetchedResultsController: NSFetchedResultsController<Assignment> = {
        let fetchRequest: NSFetchRequest<Assignment> = Assignment.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchBatchSize = 20 // TODO: May need to adjust
        
        let isInClassPredicate = predicate()
        fetchRequest.predicate = isInClassPredicate
        
        let fetchedResultsController = NSFetchedResultsController (
            fetchRequest: fetchRequest,
            managedObjectContext: coreDataController.managedContext,
            sectionNameKeyPath: #keyPath(Assignment.dueDateSection),
            cacheName: cacheName()
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Fetching error: \(error), \(error.userInfo)")
        }
        
        return fetchedResultsController
    }()
    
    func refreshFetchedResultsController(withSection section: String) {
        let isInSectionPredicate: NSPredicate
        
        switch section {
        case "Due Tomorrow":
            isInSectionPredicate = NSPredicate(format: "dueDate <= %@", Date.tomorrow as CVarArg)
        case "Due This Week":
            isInSectionPredicate = NSPredicate(format: "dueDate <= %@", Date.thisFriday as CVarArg)
        default:
            isInSectionPredicate = NSPredicate(value: true)
        }
        
        fetchedResultsController.fetchRequest.predicate = isInSectionPredicate
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Fetching error: \(error), \(error.userInfo)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.separatorColor = .separatorColor
        tableView.backgroundColor = .backgroundColor
        
        self.navigationController?.configureNavigationBar()
        
        tableView.register(UINib(nibName: "AssignmentHeaderFooterView", bundle: nil), forHeaderFooterViewReuseIdentifier: "AssignmentHeaderFooterView")
    }
    
    func configureNavigationBar() {
//        // GRADIENT
//        let colors: [UIColor] = [.lightColor, .darkColor]
//        navigationController?.navigationBar.setGradientBackground(colors: colors)
        
        navigationController?.navigationBar.barTintColor = .navigationBarTintColor
        
        // TINT COLOR
        navigationController?.navigationBar.tintColor = .tintColor
        
        // TITLE COLOR
        let textAttributes: [NSAttributedString.Key: UIColor]  = [NSAttributedString.Key.foregroundColor: .textColor]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }

}

extension ToDoTableViewController: UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = fetchedResultsController.sections else {
            return 0
        }
        
        return sections.count // TODO: optimize to just get number of sections without having to load them
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionInfo = fetchedResultsController.sections?[section] else {
            return 0
        }
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToDoAssignmentCell", for: indexPath) as! AssignmentTableViewCell
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? AssignmentTableViewCell else { return }
        
        // Get model object
        let assignment = fetchedResultsController.object(at: indexPath)
        
        // Configure cell
        cell.configure(withAssignment: assignment)
        cell.delegate = self
        cell.separatorView.isHidden = true //To remove separator view
        //        if tableView.numberOfRows(inSection: indexPath.section) == 1 {
        //        } else if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
        //        } else if indexPath.row == 0 {
        //        } else {
        //            cell.separatorView.isHidden = true //To remove separator view
        //        }
        
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.highlightColor
        cell.selectedBackgroundView = selectedBackgroundView
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return titleForHeader(inSection: section)
    }
    
    func titleForHeader(inSection section: Int) -> String {
        guard let sectionInfo = fetchedResultsController.sections?[section] else {
            return ""
        }
        
        //let numberOfRows = tableView.numberOfRows(inSection: section)
        return "\(sectionInfo.name)".uppercased()//" (\(numberOfRows))"
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let assignment = fetchedResultsController.object(at: indexPath)
        
        if hiddenSections.contains(indexPath.section) {
            return 0
        }
        
        let title = self.tableView(tableView, titleForHeaderInSection: indexPath.section)
        let sectionIsCompleted = title?.contains("Completed") ?? false
        
        if let dueDate = assignment.dueDate as Date?, dueDate != Date.tomorrow, !sectionIsCompleted {
            return 60
        } else {
            return 44
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        //return nil
        
        let title = titleForHeader(inSection: section)
        
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "AssignmentHeaderFooterView") as! AssignmentHeaderFooterView
        headerView.delegate = self
        headerView.section = section
        
        headerView.titleLabel.text = title
        //headerView.backgroundColorView.backgroundColor = UIColor.color(fromSection: title)
        headerView.titleLabel.textColor = UIColor.color(fromSection: title)
        //headerView.translatesAutoresizingMaskIntoConstraints = false
        
        if title.contains("Completed") && isCompletedHidden {
            headerView.isExpanded = false
            headerView.updateShowHideButton()
            isCompletedHidden = true
            if !hiddenSections.contains(section) { hiddenSections.append(section) }
            print("HiddenSections: \(hiddenSections)")
            
            
            //tableView.beginUpdates()
            //tableView.endUpdates()
        }
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 34
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: - Delegate
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let completeAction = UIContextualAction(style: .normal, title: "Complete", handler: { action, indexPath, completionHandler in
            self.perform(Selector("AssignmentViewController.buttonPressed(assignment:)"))
            
            completionHandler(true)
        })
        
        completeAction.backgroundColor = .nothingDueColor
        completeAction.image = UIImage(named: "greenCheckmark")!.resized(to: CGSize(width: 32, height: 32))
        
        return UISwipeActionsConfiguration(actions: [completeAction])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let scheduleAction = UIContextualAction(style: .normal, title: "Schedule", handler: { _, _, completionHandler in
            self.selectedAssignment = self.fetchedResultsController.object(at: indexPath)
            self.performSegue(withIdentifier: "ScheduleTableView", sender: self)
        })
        
        scheduleAction.image = UIImage(named: "thiccCalendarGlyph")!.resized(to: CGSize(width: 32, height: 32))
        scheduleAction.backgroundColor = UIColor(hue: 50, saturation: 70, brightness: 80, alpha: 1.0)
        
        return UISwipeActionsConfiguration(actions: [scheduleAction])
    }
    
    // MARK: - Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedAssignment = self.fetchedResultsController.object(at: indexPath)
        
        tableView.beginUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
    }
}

// MARK: NSFetchedResultsControllerDelegate

extension ToDoTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
        print("BEGAN UPDATES")
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic)
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .top)
            //tableView.scrollToRow(at: newIndexPath!, at: .none, animated: true)
        //DispatchQueue.main.async { self.reloadHeader(forSection: newIndexPath!.section) }
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        //DispatchQueue.main.async { self.reloadHeader(forSection: indexPath!.section) }
        case .move:
            print("Current Section has \(tableView.numberOfRows(inSection: indexPath!.section)) rows")
            print("New Section has \(tableView.numberOfRows(inSection: newIndexPath!.section)) rows")
            
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
            break
            
            if tableView.numberOfSections == 1 && tableView.numberOfRows(inSection: 0) == 1 && self.tableView(tableView, titleForHeaderInSection: indexPath!.section) != "Completed" {
                break
            }
            
            if tableView.numberOfRows(inSection: indexPath!.section) <= 1 || tableView.numberOfRows(inSection: newIndexPath!.section) <= 1 {
                tableView.reloadRows(at: [indexPath!], with: .automatic)
            } else {
                //tableView.reloadRows(at: [indexPath!], with: .automatic)
                tableView.moveRow(at: indexPath!, to: newIndexPath!)
            }
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .delete:
            for (index, hiddenSection) in hiddenSections.enumerated() where hiddenSection >= sectionIndex {
                hiddenSections[index] -= 1
                print("HiddenSections: \(hiddenSections)")
                if let section = tableView.headerView(forSection: hiddenSection) as? AssignmentHeaderFooterView {
                    section.section? -= 1
                }
            }
            tableView.deleteSections([sectionIndex], with: .fade)
        case .insert:
            for (index, hiddenSection) in hiddenSections.enumerated() where hiddenSection >= sectionIndex {
                hiddenSections[index] += 1
                print("HiddenSections: \(hiddenSections)")
                if let section = tableView.headerView(forSection: hiddenSection) as? AssignmentHeaderFooterView {
                    section.section? += 1
                }
            }
            
            self.tableView.insertSections([sectionIndex], with: .fade)
            
            
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        print("ENDED UPDATES")
    }
}

// MARK: Assignment Table View Cell Delegate

extension ToDoTableViewController: AssignmentTableViewCellDelegate {
    @objc func buttonPressed(assignment: Assignment) -> Bool {
        if let assignment = fetchedResultsController.fetchedObjects?.first(where: { $0 == assignment }), let toDo = assignment.toDo {
            toDo.isCompleted = !toDo.isCompleted
            assignment.isCompleted = toDo.isCompleted
            
            toDo.completionDate = NSDate()
            toDo.ckRecord["isCompleted"] = toDo.isCompleted as CKRecordValue?
            
            if toDo.isCompleted {
                assignment.dueDateSectionNumber = 5
                assignment.dueDateSection = "Completed"
            } else {
                assignment.updateDueDateSection()
            }
            
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
                        //self.alertUserOfFailure()
                        self.coreDataController.save()
                    }
                }
            }
            
            coreDataController.save()
            
            //delegate?.reloadClass(`class`)
            
            return toDo.isCompleted
        } else {
            print("Couldn't find associated assignment; look at AssignmentTableViewController: AssignmentTableViewCellDelegate")
            return true
        }
    }
    
    func scheduleButtonPressed(assignment: Assignment) {
        selectedAssignment = assignment
        performSegue(withIdentifier: "ScheduleTableView", sender: self)
    }
}

// MARK: AssignmentHeaderFooterCellDelegate

extension ToDoTableViewController: AssignmentHeaderFooterCellDelegate {
    func showHideButtonPressed(isExpanded: Bool, forSection section: Int) {
        if !isExpanded && !hiddenSections.contains(section) {
            hiddenSections.append(section)
            print("HiddenSections: \(hiddenSections)")
        } else if !isExpanded && hiddenSections.contains(section) {
            // Do nothing
        } else {
            hiddenSections.removeAll(where: { $0 == section })
            print("HiddenSections: \(hiddenSections)")
        }
        
        if self.tableView(tableView, titleForHeaderInSection: section)?.contains("Completed") ?? false {
            isCompletedHidden = !isCompletedHidden
        }
        
        tableView.beginUpdates()
        tableView.endUpdates()
    }
}

