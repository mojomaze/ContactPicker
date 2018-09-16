//
//  ContactsFetcher.swift
//  ContactPicker
//
//  Created by mwinkler on 3/15/17.
//  Copyright © 2017 Winkler Consulting. All rights reserved.
//

import UIKit
import Contacts
import AddressBook

extension String {
    func isEmail() -> Bool {
        let emailPattern: String = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailPattern)
        return emailTest.evaluate(with: self)
    }
}

enum ContactCollectionType {
    case email, phone, any
}

struct ContactCollectionItem {
    var label: String?
    var value: String?
    var type: ContactCollectionType
    var displayName: String? {
        guard let value = self.value else { return nil }
        if let label = self.label {
            return "\(label): \(value)"
        }
        return value
    }
    
    init(type: ContactCollectionType) {
        self.type = type
    }
    
    static func build(abMultiValue: ABMutableMultiValue, type: ContactCollectionType) -> [ContactCollectionItem]? {
        var collection = [ContactCollectionItem]()
        
        for i in 0..<abMultiValue.count {
            var item = ContactCollectionItem(type: type)
            if let value = ABMultiValueCopyValueAtIndex(abMultiValue, i).takeRetainedValue() as? String {
                switch type {
                case .email:
                    if value.isEmail() {
                        item.value = value
                    }
                default:
                    item.value = value
                }
            }
            
            let label = ABMultiValueCopyLabelAtIndex(abMultiValue, i).takeRetainedValue()
            item.label = ABAddressBookCopyLocalizedLabel(label).takeRetainedValue() as String
            
            guard let _ = item.value else { continue }
            collection.append(item)
        }
        guard collection.count > 0 else { return nil }
        return collection
    }
    
    @available(iOS 9.0, *)
    static func build(cnEmailAdresses: [CNLabeledValue<NSString>]) -> [ContactCollectionItem]? {
        var collection = [ContactCollectionItem]()
        
        for address in cnEmailAdresses {
            var item = ContactCollectionItem(type: .email)
            let value = address.value as String
            if value.isEmail() {
                item.value = value
            }
            item.label = address.label
            
            if let label = item.label {
                item.label = CNLabeledValue<NSString>.localizedString(forLabel: label)
            }
            
            guard let _ = item.value else { continue }
            collection.append(item)
        }
        guard collection.count > 0 else { return nil }
        return collection
        
        
    }
    
    @available(iOS 9.0, *)
    static func build(cnPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> [ContactCollectionItem]? {
        var collection = [ContactCollectionItem]()
        
        for address in cnPhoneNumbers {
            var item = ContactCollectionItem(type: .phone)
            let value = address.value as CNPhoneNumber
            item.value = value.stringValue
            item.label = address.label
            
            if let label = item.label {
                item.label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: label)
            }
            
            guard let _ = item.value else { continue }
            collection.append(item)
        }
        guard collection.count > 0 else { return nil }
        return collection
        
    }
}

struct Contact {
    var first: String?
    var last: String?
    var emailAddresses: [ContactCollectionItem]?
    var phoneNumbers: [ContactCollectionItem]?
    var imageData: Data?
    var sortName: String?
    var selected = false
    
    var displayName: String? {
        guard let first = self.first, let last = self.last, first.characters.count > 0 || last.characters.count > 0 else { return nil }
        if let first = self.first, let last = self.last {
            return [first, last].joined(separator: " ")
        }
        return self.first != nil ? self.first : self.last
    }
    
    init(first: String?, last: String?, sortName: String?) {
        self.first = first
        self.last = last
        self.sortName = sortName
    }
    
    init(abRecord: ABRecord) {
        last = ABRecordCopyValue(abRecord, kABPersonLastNameProperty).takeRetainedValue() as? String
        first = ABRecordCopyValue(abRecord, kABPersonFirstNameProperty).takeRetainedValue() as? String
        
        if let emailsMultivalueRef = ABRecordCopyValue(abRecord, kABPersonEmailProperty)?.takeRetainedValue(),
            let emailsRef = ABMultiValueCopyArrayOfAllValues(emailsMultivalueRef)?.takeRetainedValue() {
            emailAddresses = ContactCollectionItem.build(abMultiValue: emailsRef, type: .email)
        }
        
        if let phoneMultivalueRef = ABRecordCopyValue(abRecord, kABPersonEmailProperty)?.takeRetainedValue(),
            let phoneRef = ABMultiValueCopyArrayOfAllValues(phoneMultivalueRef)?.takeRetainedValue() {
            phoneNumbers = ContactCollectionItem.build(abMultiValue: phoneRef, type: .phone)
        }
        
        if ABPersonHasImageData(abRecord) {
            imageData = ABPersonCopyImageData(abRecord).takeRetainedValue() as Data
        }
        
        sortName = ContactsManager.isSortLast() ? last : first
    }
    
    @available(iOS 9.0, *)
    init(cnContact: CNContact) {
        if cnContact.isKeyAvailable(CNContactGivenNameKey) {
            first = cnContact.givenName
        }
        
        if cnContact.isKeyAvailable(CNContactFamilyNameKey) {
            last = cnContact.familyName
        }
        
        sortName = ContactsManager.isSortLast() ? last : first
        
        if cnContact.isKeyAvailable(CNContactEmailAddressesKey) {
            emailAddresses = ContactCollectionItem.build(cnEmailAdresses: cnContact.emailAddresses)
        }
        
        if cnContact.isKeyAvailable(CNContactPhoneNumbersKey) {
            phoneNumbers = ContactCollectionItem.build(cnPhoneNumbers: cnContact.phoneNumbers)
        }
        
        if cnContact.isKeyAvailable(CNContactImageDataKey) {
            imageData = cnContact.imageData
        }
    }
    
    func isValid() -> Bool {
        guard let _ = displayName else { return false }
        if let emails = emailAddresses, emails.count > 0 {
            return true
        }
        if let phones = phoneNumbers, phones.count > 0 {
            return true
        }
        return false
    }
}

struct ContactsManager {
    static func isSortLast() -> Bool {
        return Int(ABPersonGetSortOrdering()) == kABPersonSortByLastName
    }
    
    static func authorized(completion: @escaping (_ authorized: Bool) -> ()) {
        if #available(iOS 9.0, *) {
            let store = CNContactStore()
            
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized:
                completion(true)
                
            case .notDetermined:
                store.requestAccess(for: .contacts) { success, error in
                    guard error == nil && success else {
                        completion(false)
                        return
                    }
                    completion(true)
                }
                
            default:
                completion(false)
            }
            
        } else {
            let addressBook = ABAddressBookCreateWithOptions(nil, nil).takeRetainedValue()
            
            switch ABAddressBookGetAuthorizationStatus() {
            case .authorized:
                completion(true)
                
            case .notDetermined:
                ABAddressBookRequestAccessWithCompletion(addressBook, { success, error in
                    DispatchQueue.main.async {
                        completion(success)
                    }
                })
                
            default:
                completion(false)
            }
        }
    }
    
    static func fetch(completion:  @escaping (_ contacts: [Contact]) -> ()) {
        var contactsList = [Contact]()
        
        ContactsManager.authorized { authorized in
            guard authorized else {
                completion(contactsList)
                return
            }
            
            if #available(iOS 9.0, *) {
                let store = CNContactStore()
                store.requestAccess(for: .contacts, completionHandler: { (success, error) in
                    guard error == nil && success else {
                        completion(contactsList)
                        return
                    }
                    
                    let keys = [CNContactIdentifierKey, CNContactEmailAddressesKey, CNContactGivenNameKey,
                                CNContactFamilyNameKey, CNContactImageDataKey, CNContactPhoneNumbersKey]
                    
                    let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
                    request.unifyResults = true
                    if #available(iOS 10.0, *) {
                        request.mutableObjects = false
                    }
                    
                    do {
                        try store.enumerateContacts(with: request, usingBlock: { (cnContact:CNContact, stop:UnsafeMutablePointer<ObjCBool>) in
                            let contact = Contact(cnContact: cnContact)
                            if contact.isValid() {
                                contactsList.append(contact)
                            }
                        })
                        completion(contactsList)
                    } catch {
                        completion(contactsList)
                    }
                })
                
            } else {
                let addressBook = ABAddressBookCreateWithOptions(nil, nil).takeRetainedValue()
                
                let people = ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, nil, ABPersonSortOrdering(kABPersonSortByFirstName)).takeRetainedValue() as Array
                
                for abRecord: ABRecord in people {
                    let contact = Contact(abRecord: abRecord)
                    if contact.isValid() {
                        contactsList.append(contact)
                    }
                }
                completion(contactsList)
            }
        }
        
    }
    
}
