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

class Message: CloudUploadable, CoreDataUploadable {
    
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
    var coreData: NSManagedObject {
        return coreDataMessage
    }
    
    // Cloud
    var ckRecord: CKRecord // remember to set parent property
    
    // INITIALIZERS:
    
    init(fromRecord record: CKRecord, managedContext: NSManagedObjectContext) {
        // Create CoreDataMessage
        let newCoreDataMessage = CoreDataMessage(context: managedContext)
        
        newCoreDataMessage.text = record["text"] as? String
        newCoreDataMessage.timestamp = record.creationDate! as NSDate
        newCoreDataMessage.encodedSystemFields = record.encoded()
        
        self.coreDataMessage = newCoreDataMessage
        
        // Create CKRecord
        self.ckRecord = record
    }
    
    init(fromCoreDataMessage coreDataMessage: CoreDataMessage, zoneID: CKRecordZoneID) {
        self.coreDataMessage = coreDataMessage
        
        // Create CKRecord
        let newCKRecord: CKRecord
        
        if let encodedSystemFields = coreDataMessage.encodedSystemFields {
            let unarchiver = NSKeyedUnarchiver(forReadingWith: encodedSystemFields)
            unarchiver.requiresSecureCoding = true
            newCKRecord = CKRecord(coder: unarchiver)!
            unarchiver.finishDecoding()
        } else {
            newCKRecord = CKRecord(recordType: "Message", zoneID: zoneID)
        }
        
        newCKRecord["text"] = coreDataMessage.text as CKRecordValue?
        
        // TODO: Set owning conversation
        
        self.ckRecord = newCKRecord
        
        // TODO: Add owning conversation of message from core data
    }
    
    init(withText text: String, timestamp: Date, managedContext: NSManagedObjectContext, owningConversation: CKReference, zoneID: CKRecordZoneID) {
        // Create CoreDataMessage
        let newCoreDataMessage = CoreDataMessage(context: managedContext)
        newCoreDataMessage.text = text
        newCoreDataMessage.timestamp = timestamp as NSDate
        
        self.coreDataMessage = newCoreDataMessage
        
        // Create CKRecord
        let newCKRecord = CKRecord(recordType: RecordType.message.cloudValue, zoneID: zoneID)
        newCKRecord["text"] = text as CKRecordValue
        newCKRecord["owningConversation"] = owningConversation as CKRecordValue
        
        if let owningConversationReference = newCKRecord["owningConversation"] as? CKReference {
            print(owningConversationReference)
        }
        
        self.ckRecord = newCKRecord
    }
    
    // MARK: - Helper Methods
    
    func update(withRecord record: CKRecord) {
        coreDataMessage.text = record["text"] as? String
        coreDataMessage.timestamp = record["timestamp"] as? NSDate
        coreDataMessage.encodedSystemFields = record.encoded()
        
        self.ckRecord = record
    }
}
