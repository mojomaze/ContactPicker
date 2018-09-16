//
//  ViewController.swift
//  ContactPicker
//
//  Created by mwinkler on 3/15/17.
//  Copyright © 2017 Winkler Consulting. All rights reserved.
//

import UIKit

class ContactAlertAction: UIAlertAction {
    var contactItem: ContactCollectionItem?
}

class ContactsPickerViewController: UIViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    var keys = [String]()
    var sections = [String: [Contact]]()
    var filteredContacts: [Contact]?
    
    private(set) var contacts = [Contact]() {
        didSet {
            filteredContacts = nil
            (keys, sections) = keysAndSections(for: contacts)
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        ContactsManager.fetch() { contacts in
            print("Contacts created: \(contacts.count)")
            DispatchQueue.main.async {
                self.contacts = contacts
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func present(contact: Contact) {
        var title = "Invite"
        if let name = contact.displayName {
            title += " \(name)"
        }
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        if let alertActions = alertActions(for: contact), alertActions.count > 0 {
            for action in alertActions {
                controller.addAction(action)
            }
            
            controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(controller, animated: true, completion: nil)
        }
    }
    
    func alertActions(for contact: Contact) -> [ContactAlertAction]? {
        var actions = [ContactAlertAction]()
        if let phones = contact.phoneNumbers {
            for phoneNumber in phones {
                if let action = alertAction(for: phoneNumber) {
                    actions.append(action)
                }
            }
        }
        
        if let emails = contact.emailAddresses {
            for email in emails {
                if let action = alertAction(for: email) {
                    actions.append(action)
                }
            }
        }
        
        guard actions.count > 0 else { return nil }
        return actions
    }
    
    func alertAction(for item: ContactCollectionItem) -> ContactAlertAction? {
        if let name = item.displayName {
            let alertAction = ContactAlertAction(title: name, style: .default, handler: contactActionHandler)
            alertAction.contactItem = item
            return alertAction
        }
        return nil
    }
    
    let contactActionHandler: (_ alertAction: UIAlertAction) -> Void = {
        alertAction in
        if let action = alertAction as? ContactAlertAction, let item = action.contactItem {
            print("action for type: \(item.type)")
        }
    }
    
    func contact(at indexPath: IndexPath) -> Contact? {
        if let filteredContacts = self.filteredContacts {
            guard filteredContacts.count > indexPath.row else { return nil }
            return filteredContacts[indexPath.row]
        }
        
        guard keys.count > indexPath.section else { return nil }
        guard let contacts = sections[keys[indexPath.section]], contacts.count > indexPath.row else { return nil }
        return contacts[indexPath.row]
    }
    
    private func keysAndSections(for contacts: [Contact]) -> ([String], [String: [Contact]]){
        var keys = [String]()
        var sections = [String: [Contact]]()
        
        guard contacts.count > 0 else { return (keys, sections) }
        
        let sortedContacts = contacts.sorted {
            guard let first = $0.sortName, let second = $1.sortName else { return true }
            return first < second
        }
        
        keys = Array(Set(sortedContacts.map { contact -> String in
            if let name = contact.sortName, let firstChar = name.characters.first {
                return String(firstChar)
            }
            return ""
        })).sorted()
        
        for key in keys {
            sections[key] = sortedContacts.filter {
                var include = false
                if let name = $0.sortName, let firstChar = name.characters.first, let keyChar = key.characters.first {
                    include = firstChar == keyChar
                }
                return include
            }
        }
        
        return (keys, sections)
    }
}

extension ContactsPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        guard filteredContacts == nil else { return 1 }
        return keys.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard filteredContacts == nil, keys.count > section else { return nil }
        return keys[section]
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard filteredContacts == nil else { return nil }
        return keys
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let contacts = filteredContacts {
            return contacts.count
        }
        guard keys.count > section else { return 0 }
        guard let contacts = sections[keys[section]] else { return 0 }
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ContactsPickerCell.cellReuseIdentifier, for: indexPath) as? ContactsPickerCell else { return UITableViewCell() }
        
        guard let contact = contact(at: indexPath) else { return cell }
        cell.contact = contact
        return cell
    }
}

extension ContactsPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let contact = contact(at: indexPath) {
            present(contact: contact)
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

extension ContactsPickerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else {
            filteredContacts = nil
            tableView.reloadData()
            return
        }
        
        let search = searchText.lowercased()
            
        filteredContacts = contacts.filter {
            $0.first?.lowercased().range(of: search) != nil || $0.last?.lowercased().range(of: search) != nil
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        filteredContacts = nil
        searchBar.resignFirstResponder()
        tableView.reloadData()
    }
}
