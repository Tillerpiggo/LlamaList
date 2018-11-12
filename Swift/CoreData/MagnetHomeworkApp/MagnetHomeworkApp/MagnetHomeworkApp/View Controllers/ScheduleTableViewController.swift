//
//  ScheduleTableViewController.swift
//  MagnetHomeworkApp
//
//  Created by Tyler Gee on 11/8/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

protocol ScheduleTableViewControllerDelegate {
    func reloadAssignment(_ assignment: Assignment)
}

class ScheduleTableViewController: UITableViewController {
    
    var assignment: Assignment!
    var dueDate: Date?
    var isDueDatePickerHidden = true
    var coreDataController: CoreDataController!
    var delegate: ScheduleTableViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.barTintColor = .navigationBarColor
        
        dueDate = (assignment.dueDate as Date?)
        
        dueDatePicker.date = dueDate ?? Date.tomorrow
        
        setDueDateLabelText()
        setThisWeekdayText()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCheckmarks()
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var dueDateLabel: UILabel!
    @IBOutlet weak var dueDatePicker: UIDatePicker!
    @IBOutlet weak var dueOnWeekdayLabel: UILabel!
    
    
    // MARK: - IBActions
    
    @IBAction func saveButtonPressed(_ sender: Any) {
        save()
    }
    
    @IBAction func dueDatePickerChanged(_ sender: UIDatePicker) {
        dueDate = sender.date.firstSecond
        setDueDateLabelText()
        setCheckmarks()
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    func save() {
        assignment.dueDate = dueDate as NSDate?
        assignment.updateDueDateSection()
        assignment.ckRecord["dueDate"] = dueDate as CKRecordValue?
        coreDataController.save()
        
        delegate?.reloadAssignment(assignment)
        
        self.dismiss(animated: true)
    }
    
    func setDueDateLabelText() {
        dueDateLabel.text = Date.stringFromDate(dueDate).firstLetterCapitalized
    }
    
    func setThisWeekdayText() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        if weekday >= 1 && weekday <= 5 {
            dueOnWeekdayLabel.text = "Due this Friday"
        } else {
            dueOnWeekdayLabel.text = "Due this coming Monday"
        }
    }
    
    func setCheckmarks() {
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 1)) {
            cell.accessoryType = (dueDate == Date.tomorrow) ? .checkmark : .none
        }
        if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 1)) {
            if dueOnWeekdayLabel.text == "Due this Friday" {
                cell.accessoryType = (dueDate == Date.thisFriday) ? .checkmark : .none
            } else if dueOnWeekdayLabel.text == "Due this coming Monday" {
                cell.accessoryType = (dueDate == Date.thisMonday) ? .checkmark : .none
            }
        }
    }
}

// MARK: - Table View Data Source

 extension ScheduleTableViewController {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath {
        case [0,0]: // Due Date Cell
            return isDueDatePickerHidden ? 44 : 200
        default:
            return 44
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath {
        case [0,0]:
            isDueDatePickerHidden = !isDueDatePickerHidden
            
            dueDateLabel.textColor = isDueDatePickerHidden ? .black: .actionTextColor
            
            tableView.beginUpdates()
            tableView.endUpdates()
        case [1,0]: // Due Tomorrow Cell
            dueDate = Date.tomorrow
            dueDatePicker.date = dueDate!
        case [1,1]: // Due Friday Cell
            let weekday: Date = dueOnWeekdayLabel.text == "Due this Friday" ? .thisFriday : .thisMonday
            
            dueDate = weekday
            dueDatePicker.date = dueDate!
        case [2,0]:
            dueDate = nil
            dueDatePicker.date = Date()
        default:
            print("Nonexistent cell has been selected... hm... IndexPath: \(indexPath)")
        }
        
        setDueDateLabelText()
        setCheckmarks()
        tableView.deselectRow(at: indexPath, animated: true)
    }
 }