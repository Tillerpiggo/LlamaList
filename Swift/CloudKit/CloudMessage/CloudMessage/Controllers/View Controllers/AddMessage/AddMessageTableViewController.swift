//
//  AddMessageTableViewController.swift
//  CloudMessage
//
//  Created by Tyler Gee on 7/31/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//

import UIKit
import CloudKit

protocol AddMessageTableViewControllerDelegate {
    func addedMessage(_ message: Message)
}

class AddMessageTableViewController: UITableViewController {
    
    // PROPERTIES:
    
    public var message: Message?
    public var delegate: AddMessageTableViewControllerDelegate?
    public var conversationReference: CKReference?

    // IBOUTLETS:
    
    @IBOutlet weak private var textField: UITextField!
    @IBOutlet weak private var saveButton: UIBarButtonItem!
    
    
    // VIEW DID LOAD:
    
    override func viewDidLoad() {
        super.viewDidLoad()
        update(with: message)
        updateSaveButton()
    }
    
    // IBACTIONS:
    
    @IBAction private func saveButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        save()
    }
    
    @IBAction private func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func textFieldTextChanged(_ sender: UITextField) {
        updateSaveButton()
    }
    
    // DELEGATE:
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // HELPER METHODS:
    
    private func save() {
        // This is the edit case. Don't worry about it for this app
        guard message == nil else { return }
        
        if let conversationReference = conversationReference {
            let newMessage = Message(withText: textField.text!, timestamp: Date(), owningConversation: conversationReference)
            delegate?.addedMessage(newMessage)
        }
    }
    
    private func update(with message: Message?) {
        guard let message = message else { return }
        
        textField.text = message.text
    }
    
    private func updateSaveButton() {
        let text = textField.text ?? ""
        saveButton.isEnabled = !text.isEmpty
    }

}
