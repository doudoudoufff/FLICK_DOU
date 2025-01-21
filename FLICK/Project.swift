import Foundation
import SwiftUI

struct Project: Identifiable {
    let id = UUID()
    var name: String
    var director: String
    var producer: String
    var startDate: Date
    var endDate: Date?
    var status: ProjectStatus
    var color: Color
    var tasks: [ProjectTask]
    
    enum ProjectStatus {
        case planning
        case shooting
        case postProduction
        case completed
    }
    
    init(name: String, 
         director: String = "", 
         producer: String = "", 
         startDate: Date = Date(), 
         status: ProjectStatus = .planning, 
         color: Color = .blue,
         tasks: [ProjectTask] = []) {
        self.name = name
        self.director = director
        self.producer = producer
        self.startDate = startDate
        self.status = status
        self.color = color
        self.tasks = tasks
    }
} 