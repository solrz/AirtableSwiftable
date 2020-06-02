//
//  Airtable.swift
//  whabitchme WatchKit Extension
//
//  Created by 郭勁辰 on 2020/6/2.
//  Copyright © 2020 kjc. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire

typealias APIKey = String
typealias DatabaseID = String
typealias TableName = String
typealias Filter = Dictionary<String, Any>
typealias RecordID = String

class Airtable : ObservableObject, CustomStringConvertible {
    var description: String{
        get{
            "Airtable@\(destUrl)"
        }
    }
    
    @Published var apiKey: APIKey
    @Published var DBID: DatabaseID
    @Published var tableName: TableName
    @Published var cachedRecords = Dictionary<RecordID, Record>()
    subscript(ID:String) -> Record{
        get{
            if let record = self.cachedRecords[ID]{
                return record
            }else{
                return Record(in: self, fields: [:], id: ID)
            }
        }
        set{
            cachedRecords[ID] = newValue
        }
    }
    fileprivate var queuedCreateRequests = [Record]()
    fileprivate var queuedUpdateRequests = Dictionary<RecordID, Parameters>()
    fileprivate var destUrl: String {
        get {
            return "https://api.airtable.com/v0/\(DBID)/\(tableName)/"
        }
    }
    fileprivate var authorizeHeader: HTTPHeaders {
        get {
            [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ]
        }
    }
    private var createTimer = Timer()
    private var updateTimer = Timer()
    
    init(apiKey: APIKey, DBID: DatabaseID, tableName: TableName) {
        self.apiKey = apiKey
        self.DBID = DBID
        self.tableName = tableName
        self.createTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(backgroundCreate), userInfo: nil, repeats: true)
        self.updateTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(backgroundUpdate), userInfo: nil, repeats: true)
        self.list(after: {_ in })
    }
    
    public func list(after completion: @escaping (_ records: [Record]) -> Void) {
        retrieve(destUrl: self.destUrl, after: completion)
    }
    
    
    public func newRecord(_ fields: Parameters) {
        Record(in: self, fields: fields)
    }
    
    public func newRecords(_ fields: [Parameters]) {
        _ = fields.map {
            Record(in: self, fields: $0)
        }
    }
    
    public func readRecord(id:String, after completion: @escaping (_ records: [Record]) -> Void = {_ in }) {
        retrieve(destUrl: self.destUrl+id, after: completion)
    }
    
    public func updateRecord(id:String, fields: Parameters) {
        self.queuedUpdateRequests[id] = fields
    }
    
    public func updateRecords(_ records: Dictionary<String,Parameters>) {
        for (id, fields) in records{
            self.queuedUpdateRequests[id] = fields
        }
    }
    
    public func deleteRecord(id:[String], after completion: @escaping (_ records: [Record]) -> Void = {_ in }) {
        let deletingRecords = id.map{Record(in: self, fields: [:], id: $0)}
        modify(records: deletingRecords, method: .delete, after: completion)
    }
    
    
    fileprivate func create(_ records: [Record], after completion: @escaping (_ records: [Record]) -> Void = {_ in
        }) {
        modify(records: records, method: .post, after: completion)
    }
    
    fileprivate func update(_ records: [Record], after completion: @escaping (_ records: [Record]) -> Void = {_ in
        }) {
        modify(records: records, method: .patch, after: completion)
    }
    
    fileprivate func retrieve(destUrl: String, filter:Parameters=[:], after completion: @escaping (_ records: [Record]) -> Void = {_ in }) {
        
        // TODO: - add paging
        AF.request(destUrl,
                   method: .get,
                   parameters: filter,
                   headers: self.authorizeHeader
        )
            .responseJSON { resp in
                if self.isErrorFree(resp) {
                    let json = JSON(resp.value!)
                    var records = [Record]()
                    if json["offset"].exists(){
                        var offsetedFilter = filter
                        offsetedFilter["offset"] = json["offset"]
                        self.retrieve(destUrl: self.destUrl, filter: offsetedFilter)
                    }
                    if json["records"].exists() {
                        records = json["records"].arrayValue.map { recordJson in
                            
                            Record(in: self, fields: recordJson["fields"].dictionaryValue, id: recordJson["id"].stringValue)
                            
                        }
                    } else {
                        records = [
                            Record(in: self, fields: json["fields"].dictionaryValue, id: json["id"].stringValue)
                        ]
                    }
                    for record in records {
                        self.cachedRecords[record.id] = record
                    }
                    completion(records)
                }
        }
    }
    
    fileprivate func modify(records: [Record], method: HTTPMethod, after completion: @escaping (_ records: [Record]) -> Void) {
        
        let paramRecords: Parameters = [
            "records": records.map{$0.rawJson}
            
        ]
        AF.request(destUrl,
                   method: method,
                   parameters: JSON(paramRecords).object as? Parameters,
                   encoding: JSONEncoding.default,
                   headers: self.authorizeHeader
        )
            .responseJSON { resp in
                print(resp)
                if self.isErrorFree(resp) {
                    var records = [Record]()
                    let json = JSON(resp.value!)
                    if json["records"].exists() {
                        records = json["records"].arrayValue.map { recordJson in
                            Record(in: self, fields: recordJson["fields"].dictionaryValue, id: recordJson["id"].stringValue)
                            
                        }
                    } else {
                        records = [
                            Record(in: self, fields: json["fields"].dictionaryValue, id: json["id"].stringValue)
                        ]
                    }
                    for record in records {
                        self.cachedRecords[record.id] = record
                    }
                    completion(records)
                }
        }
    }
    
    fileprivate func isErrorFree(_ response: AFDataResponse<Any>) -> Bool {
        guard let result = response.value else {
            return false
            
        }
        let json = JSON(result)
        if let _ = json.dictionary {
            if json["error"].exists() {
                return false
                
            }
        }
        return !json["error"].exists()
    }
    
    @objc private func backgroundCreate() {
        //    print(self.queuedCreateRequests as Array)
        let creatingRecords = self.queuedCreateRequests.suffix(10)
        if creatingRecords.count != 0 {
            //        print(creatingRecords)
            self.queuedCreateRequests.removeFirst(creatingRecords.count)
            let records = creatingRecords.map{$0}
            create(records)
        }
    }
    
    @objc private func backgroundUpdate() {
        let updatingRecords = self.queuedUpdateRequests.suffix(10)
        
        if updatingRecords.count != 0 {
            for (id, fields) in updatingRecords{
                self.queuedUpdateRequests[id] = fields
            }
            print(self.queuedUpdateRequests)
            update(updatingRecords.map{Record(in: self, fields: $0.value, id: $0.key)})
        }
    }
}

class Record:ObservableObject, CustomStringConvertible {
    var description: String{
        get{
            "Record(id:\(id), fields:\(fields))"
        }
    }
    var AT: Airtable
    var id: String
    @Published var fields: Parameters
    @Published var modifiedFields = Parameters()
    var rawJson:JSON{
        get{
            var rawjson = Parameters()
            if id != "Not Synced"{
                rawjson["id"] = id
            }
            rawjson["fields"] = fields
            return JSON(rawjson)
        }
    }
    init(in airtable: Airtable, fields: Parameters, id: String = "Not Synced") {
        self.AT = airtable
        self.id = id
        self.fields = fields
        if id == "Not Synced" {
            AT.queuedCreateRequests += [self]
        }
    }
    
    
    fileprivate func updateFields(attr: String, newValue: Any) {
        self.fields[attr] = newValue
        self.modifiedFields[attr] = newValue
        if self.AT.queuedUpdateRequests[self.id] != nil{
            self.AT.queuedUpdateRequests[self.id]![attr] = newValue
        }else{
            self.AT.queuedUpdateRequests[self.id] = [:]
            self.AT.queuedUpdateRequests[self.id]![attr] = newValue
        }
    }
    
    subscript(attr: String) -> String {
        get {
            JSON(self.fields[attr] ?? [:]).stringValue
        }
        set {
            updateFields(attr: attr, newValue: newValue)
        }
    }
    
    subscript(attr: String) -> Int {
        get {
            JSON(self.fields[attr] ?? [:]).intValue
        }
        set {
            updateFields(attr: attr, newValue: newValue)
        }
    }
    
    subscript(attr: String) -> Bool {
        get {
            JSON(self.fields[attr] ?? [:]).bool ?? false
        }
        set {
            updateFields(attr: attr, newValue: newValue)
        }
    }
    
    subscript(attr: String) -> Array<String> {
        get {
            JSON(self.fields[attr] ?? [:]).arrayValue.map {
                $0.string ?? ""
            }
        }
        set {
            updateFields(attr: attr, newValue: newValue)
        }
    }
    
    subscript(attr: String) -> Array<Record> {
        get {
            JSON(self.fields[attr] ?? [:]).arrayValue.map {
                self.AT.cachedRecords[$0.string!]!
            }
        }
    }
    
}
