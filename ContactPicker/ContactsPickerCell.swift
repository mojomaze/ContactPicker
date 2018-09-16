//
//  ContactPickerCell.swift
//  ContactPicker
//
//  Created by mwinkler on 3/17/17.
//  Copyright © 2017 Winkler Consulting. All rights reserved.
//

import UIKit

class ContactsPickerCell: UITableViewCell {
    
    static let cellReuseIdentifier = "ContactPickerCell"
    
    let boldFont = UIFont.boldSystemFont(ofSize: 15)
    let regFont = UIFont.systemFont(ofSize: 15)
    var boldAttributes: [String: Any] {
        return [NSFontAttributeName: boldFont]
    }
    var regAttributes: [String: Any] {
        return [NSFontAttributeName: regFont]
    }
    
    var contact: Contact? {
        didSet {
            updateDisplay()
        }
    }
    
    func updateDisplay() {
        guard let contact = self.contact, let name = attributedName() else {
            self.textLabel?.attributedText = nil
            self.detailTextLabel?.text = nil
            setSelected(false, animated: false)
            return
        }
        self.textLabel?.attributedText = name
        setSelected(contact.selected, animated: false)
        accessoryType = contact.selected ? .checkmark : .none
    }
    
    
    private func attributedName() -> NSAttributedString? {
        guard let name = contact?.displayName else { return nil }
        let text = NSMutableAttributedString(string: name, attributes: regAttributes)
        if let range = boldRange() {
            text.setAttributes(boldAttributes, range: range)
        }
        return text
        
    }
    
    private func boldRange() -> NSRange? {
        guard let contact = self.contact else { return nil }
        if let first = contact.first, let last = contact.last {
            if ContactsManager.isSortLast() {
                return NSMakeRange(first.characters.count + 1, last.characters.count)
            }
            return NSMakeRange(0, first.characters.count)
        }
        if let name = contact.last {
           return NSMakeRange(0, name.characters.count)
        }
        if let name = contact.first {
            return NSMakeRange(0, name.characters.count)
        }
        return nil
    }
    
    
    
}
