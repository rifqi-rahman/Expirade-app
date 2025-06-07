//
//  DateParser.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import Foundation

// MARK: - Date Parser Utility
struct DateParser {
    
    // MARK: - Main parsing function
    static func parseExpirationDate(from texts: [String]) -> Date? {
        // Try to find and parse dates from all detected text strings
        for text in texts {
            if let date = attemptDateParsing(from: text) {
                return date
            }
        }
        return nil
    }
    
    // MARK: - Private parsing methods
    private static func attemptDateParsing(from text: String) -> Date? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Try different parsing strategies in order of specificity
        
        // 1. Try EXP MMM YYYY format (e.g., "EXP NOV 2027", "EXPIRES JAN 2025")
        if let date = parseExpMMMyyyy(from: cleanedText) {
            return date
        }
        
        // 2. Try DD/MM/YYYY format (e.g., "15/11/2025")
        if let date = parseDDMMYYYY(from: cleanedText) {
            return date
        }
        
        // 3. Try DD-MM-YY format (e.g., "15-11-25")
        if let date = parseDDMMYY(from: cleanedText) {
            return date
        }
        
        // 4. Try MM/YYYY format (e.g., "11/2025")
        if let date = parseMMYYYY(from: cleanedText) {
            return date
        }
        
        // 5. Try MMYY format (e.g., "1127" for Nov 2027)
        if let date = parseMMYY(from: cleanedText) {
            return date
        }
        
        return nil
    }
    
    // MARK: - Format-specific parsing methods
    
    /// Parse EXP MMM YYYY format (e.g., "EXP NOV 2027", "EXPIRES JAN 2025")
    private static func parseExpMMMyyyy(from text: String) -> Date? {
        // Regex to match EXP/EXPIRES followed by month and year
        let expPatterns = [
            #"(?:EXP|EXPIRES?)\s*([A-Z]{3})\s*(\d{4})"#,
            #"([A-Z]{3})\s*(\d{4})"#  // Just month year without EXP prefix
        ]
        
        for pattern in expPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let components = matchedText.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty && !$0.contains("EXP") }
                
                if components.count >= 2 {
                    let monthStr = components[0]
                    let yearStr = components[1]
                    
                    if let month = parseMonth(from: monthStr),
                       let year = Int(yearStr) {
                        return createDate(day: 1, month: month, year: year)
                    }
                }
            }
        }
        return nil
    }
    
    /// Parse DD/MM/YYYY format (e.g., "15/11/2025")
    private static func parseDDMMYYYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})/(\d{1,2})/(\d{4})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "/")
            
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let year = Int(components[2]) {
                return createDate(day: day, month: month, year: year)
            }
        }
        return nil
    }
    
    /// Parse DD-MM-YY format (e.g., "15-11-25")
    private static func parseDDMMYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})-(\d{1,2})-(\d{2})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "-")
            
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let yearTwoDigit = Int(components[2]) {
                
                // Convert 2-digit year to 4-digit (assume 20xx for years 00-99)
                let year = yearTwoDigit < 50 ? 2000 + yearTwoDigit : 1900 + yearTwoDigit
                return createDate(day: day, month: month, year: year)
            }
        }
        return nil
    }
    
    /// Parse MM/YYYY format (e.g., "11/2025")
    private static func parseMMYYYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})/(\d{4})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "/")
            
            if components.count == 2,
               let month = Int(components[0]),
               let year = Int(components[1]),
               month >= 1 && month <= 12 {
                return createDate(day: 1, month: month, year: year)
            }
        }
        return nil
    }
    
    /// Parse MMYY format (e.g., "1127" for Nov 2027)
    private static func parseMMYY(from text: String) -> Date? {
        // Look for 4-digit patterns that could be MMYY
        let pattern = #"\d{4}"#
        
        // Use NSRegularExpression for multiple matches
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let matchedText = String(text[range])
                
                if matchedText.count == 4 {
                    let monthStr = String(matchedText.prefix(2))
                    let yearStr = String(matchedText.suffix(2))
                    
                    if let month = Int(monthStr),
                       let yearTwoDigit = Int(yearStr),
                       month >= 1 && month <= 12 {
                        
                        // Convert 2-digit year to 4-digit (assume 20xx for years 00-99)
                        let year = yearTwoDigit < 50 ? 2000 + yearTwoDigit : 1900 + yearTwoDigit
                        return createDate(day: 1, month: month, year: year)
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Helper methods
    
    /// Convert month abbreviation to month number
    private static func parseMonth(from monthStr: String) -> Int? {
        let monthMap: [String: Int] = [
            "JAN": 1, "JANUARY": 1,
            "FEB": 2, "FEBRUARY": 2,
            "MAR": 3, "MARCH": 3,
            "APR": 4, "APRIL": 4,
            "MAY": 5,
            "JUN": 6, "JUNE": 6,
            "JUL": 7, "JULY": 7,
            "AUG": 8, "AUGUST": 8,
            "SEP": 9, "SEPT": 9, "SEPTEMBER": 9,
            "OCT": 10, "OCTOBER": 10,
            "NOV": 11, "NOVEMBER": 11,
            "DEC": 12, "DECEMBER": 12
        ]
        
        return monthMap[monthStr.uppercased()]
    }
    
    /// Create Date object with validation
    private static func createDate(day: Int, month: Int, year: Int) -> Date? {
        // Validate date components
        guard month >= 1 && month <= 12,
              day >= 1 && day <= 31,
              year >= 1900 && year <= 2100 else {
            return nil
        }
        
        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = year
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        
        let calendar = Calendar.current
        return calendar.date(from: dateComponents)
    }
}

// MARK: - DateParser Extensions for Testing and Debugging
extension DateParser {
    
    /// Test function to validate parser with sample inputs
    static func testParsing() {
        let testCases = [
            "EXP NOV 2027",
            "EXPIRES JAN 2025",
            "15/11/2025",
            "05-12-24",
            "11/2025",
            "1127",
            "JAN 2024",
            "INVALID TEXT"
        ]
        
        print("🧪 Testing DateParser:")
        for testCase in testCases {
            if let date = parseExpirationDate(from: [testCase]) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                print("✅ '\(testCase)' → \(formatter.string(from: date))")
            } else {
                print("❌ '\(testCase)' → No date found")
            }
        }
        print("---")
    }
} 