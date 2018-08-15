//
//  Message.swift
//  CloudMessage2
//
//  Created by Tyler Gee on 8/4/18.
//  Copyright © 2018 Beaglepig. All rights reserved.
//


import Foundation
import CloudKit
import CoreData

class Message: CloudUploadable {
    
    // PROPERTIES:
    
    var text: String { return coreDataMessage.text ?? "" }
    var timestamp: Date { return (coreDataMessage.timestamp ?? NSDate()) as Date }
    
    var formattedTimestamp: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let formattedTimestamp = dateFormatter.string(from: timestamp)
        return formattedTimestamp
    }
    
    // Core Data
    var coreDataMessage: CoreDataMessage
    
    // Cloud
    var ckRecord: CKRecord? // remember to set parent property
    
    // INITIALIZERS:
    
    init(fromRecord record: CKRecord, managedContext: NSManagedObjectContext) {
        // Create CoreDataMessage
        let newCoreDataMessage = CoreDataMessage(context: managedContext)
        newCoreDataMessage.text = record["text"] as? String
        newCoreDataMessage.timestamp = record.creationDate! as NSDate
        
        self.coreDataMessage = newCoreDataMessage
        
        // Create CKRecord
        self.ckRecord = record
    }
    
    init(withText text: String, timestamp: Date, managedContext: NSManagedObjectContext, owningConversation: CKReference? = nil) {
        // Create CoreDataMessage
        let newCoreDataMessage = CoreDataMessage(context: managedContext)
        newCoreDataMessage.text = text
        newCoreDataMessage.timestamp = timestamp as NSDate
        
        self.coreDataMessage = newCoreDataMessage
        
        // CKRecord
        let newCKRecord = CKRecord(recordType: "Message")
        newCKRecord["text"] = text as CKRecordValue
        
        if let owningConversation = owningConversation {
            newCKRecord["owningConversation"] = owningConversation
        }
        
        self.ckRecord = newCKRecord
    }
}