//
//  FeedViewController.swift
//  twitter-project
//
//  Created by Дмитрий Матвеенко on 21.07.2018.
//  Copyright © 2018 Дмитрий Матвеенко. All rights reserved.
//

import UIKit
import RealmSwift
import Firebase

class FeedViewController: UIViewController {
    
    var twitList: Results<Messages>!
    
    var ref: DatabaseReference!
    var user: Username!
    
    @IBOutlet var tableTwitContent: UITableView!
    @IBAction func close(segue: UIStoryboardSegue) {
        tableTwitContent.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableTwitContent.delegate = self
        tableTwitContent.dataSource = self
        
        realm = try! Realm()
        
        guard let currentUser = Auth.auth().currentUser else { return }
        user = Username(user: currentUser)
        ref = Database.database().reference(withPath: "users").child(String(user.uid)).child("twits")
        
        initialDataToFirebase()
        if isLoginFirst {
            initialDataToRealm()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        twitList = realm.objects(Messages.self)
        self.twitList = self.twitList.sorted(byKeyPath: "createdAt", ascending: false)
        
        self.tableTwitContent.setEditing(false, animated: true)
        self.tableTwitContent.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableTwitContent.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Button Action
    
    @IBAction func signOutTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: user.email, message: "You can update the data or sign out", preferredStyle: .alert)
        alert.addTextField { (textFieldEmail) in
            textFieldEmail.placeholder = "Email"
        }
        alert.addTextField { (textFieldPassword) in
            textFieldPassword.placeholder = "Password"
            textFieldPassword.isSecureTextEntry = true
        }
        
        let update = UIAlertAction(title: "Save", style: .default) { _ in
            let currentUser = Auth.auth().currentUser
            
            if alert.textFields?.first?.text != "" {
                let textFieldEmail = alert.textFields?.first?.text
                
                currentUser?.updateEmail(to: textFieldEmail!) { error in
                    if let error = error {
                        print(error)
                    } else {
                        self.user.email = textFieldEmail!
                        
                        let userRef = Database.database().reference(withPath: "users").child(String(self.user.uid))
                        userRef.updateChildValues(["email": textFieldEmail!])
                    }
                }
            }
            
            if alert.textFields?[1].text != "" {
                let textFieldPassword = alert.textFields?[1].text
                
                currentUser?.updatePassword(to: textFieldPassword!) { error in
                    if let error = error {
                        print(error)
                    }
                }
            }
        }
        
        let exit = UIAlertAction(title: "Exit", style: .destructive) { _ in
            
            do {
                try Auth.auth().signOut()
            } catch {
                print(error.localizedDescription)
            }
            self.dismiss(animated: true, completion: nil)
            
            twits.removeAll()
            try! realm.write {
                realm.deleteAll()
            }
            
            isLoginFirst = false
            isLogin = false
            self.performSegue(withIdentifier: "unwindToLogin", sender: nil)
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(update)
        alert.addAction(cancel)
        alert.addAction(exit)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Delete and edit from table
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let delete = UITableViewRowAction(style: .default, title: "Delete") { (action, indexPath) in
            let item = self.twitList[indexPath.row]
            
            let twit = twits[indexPath.row]
            twits.remove(at: indexPath.row)
            twit.reference?.removeValue()
            
            try! realm.write({
                realm.delete(item)
            })
            
            tableView.deleteRows(at:[indexPath], with: .automatic)
        }
        
        let edit = UITableViewRowAction(style: .default, title: "Edit") { (action, indexPath) in
            let twitIndex = indexPath.row
            self.performSegue(withIdentifier: "editTwit", sender: twitIndex)
        }
        
        edit.backgroundColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        delete.backgroundColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
        return [delete, edit]
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addSegue" {
            let destinationEditViewController = (segue.destination as! UINavigationController).topViewController as! AddTwitViewController
            destinationEditViewController.ref = ref
            destinationEditViewController.user = user
        }
        
        if segue.identifier == "editTwit" {
            let destinationEditViewController = (segue.destination as! UINavigationController).topViewController as! EditTwitViewController
            
            let index = sender as! Int
            
            let object = twitList[index]
            let objectToRealm = object
            let objectToFirebase = twits[index]
            let editText = object.text
            
            destinationEditViewController.editTwitText = editText
            destinationEditViewController.ref = ref
            destinationEditViewController.user = user
            destinationEditViewController.twitRealmToEdit = objectToRealm
            destinationEditViewController.twitFirebaseToEdit = objectToFirebase
        }
    }
}

extension FeedViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return twitList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! FeedTableViewCell
        
        let item = twitList[indexPath.row]
        cell.textTwitLabel.text = item.text
        return cell
    }
}