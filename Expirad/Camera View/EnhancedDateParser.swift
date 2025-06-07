//
//  EnhancedDateParser.swift
//  Expirad
//
//  Created by Rifqi Rahman on 07/06/25.
//

import Foundation

// MARK: - Enhanced Date Parser for Medicine Packages
struct EnhancedDateParser {
    
    // MARK: - Main parsing function
    static func parseExpirationDate(from texts: [String]) -> Date? {
        print("🔍 Parsing texts: \(texts)")
        
        // Sort texts by priority - those with expiration keywords first
        let prioritizedTexts = texts.sorted { text1, text2 in
            let keywords = ["EXP", "EXPIRE", "BEST", "USE BY", "BB", "BBD", "ED"]
            let hasKeyword1 = keywords.contains { text1.uppercased().contains($0) }
            let hasKeyword2 = keywords.contains { text2.uppercased().contains($0) }
            return hasKeyword1 && !hasKeyword2
        }
        
        // Try to find and parse dates from all detected text strings
        for text in prioritizedTexts {
            if let date = attemptDateParsing(from: text) {
                print("✅ Successfully parsed date: \(date) from text: \(text)")
                return date
            }
        }
        
        print("❌ No valid expiration date found in provided texts")
        return nil
    }
    
    // MARK: - Private parsing methods
    private static func attemptDateParsing(from text: String) -> Date? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        print("🔍 Attempting to parse: '\(cleanedText)'")
        
        // Try different parsing strategies in order of specificity and confidence
        
        // 1. Try keyword-based patterns first (highest confidence)
        if let date = parseKeywordBasedDate(from: cleanedText) {
            return date
        }
        
        // 2. Try EXP MMM YYYY format (e.g., "EXP NOV 2027", "EXPIRES JAN 2025")
        if let date = parseExpMMMyyyy(from: cleanedText) {
            return date
        }
        
        // 3. Try DD/MM/YYYY format (e.g., "15/11/2025")
        if let date = parseDDMMYYYY(from: cleanedText) {
            return date
        }
        
        // 4. Try DD-MM-YY format (e.g., "15-11-25")
        if let date = parseDDMMYY(from: cleanedText) {
            return date
        }
        
        // 5. Try MM/YYYY format (e.g., "11/2025")
        if let date = parseMMYYYY(from: cleanedText) {
            return date
        }
        
        // 6. Try MMYY format (e.g., "1127" for Nov 2027)
        if let date = parseMMYY(from: cleanedText) {
            return date
        }
        
        // 7. Try spaced formats (e.g., "15 11 25", "NOV 2027")
        if let date = parseSpacedDate(from: cleanedText) {
            return date
        }
        
        // 8. Try dotted formats (e.g., "15.11.2025")
        if let date = parseDottedDate(from: cleanedText) {
            return date
        }
        
        return nil
    }
    
    // MARK: - Enhanced keyword-based parsing for medicine packages
    private static func parseKeywordBasedDate(from text: String) -> Date? {
        let keywordPatterns = [
            // Common expiration keywords with dates
            #"(?:EXP\.?:?|EXPIRES?:?|BEST\s+BEFORE:?|USE\s+BY:?|BB:?|BBD:?|ED:?)\s*(\d{1,2}[\/\.\-\s]\d{1,2}[\/\.\-\s]\d{2,4})"#,
            #"(?:EXP\.?:?|EXPIRES?:?)\s*([A-Z]{3})\s*(\d{2,4})"#,
            #"(?:EXP\.?:?|EXPIRES?:?)\s*(\d{1,2})\s*([A-Z]{3})\s*(\d{2,4})"#,
            #"(?:BAIK\s+DIGUNAKAN\s+SEBELUM|KADALUARSA)\s*(\d{1,2}[\/\.\-\s]\d{1,2}[\/\.\-\s]\d{2,4})"#
        ]
        
        for pattern in keywordPatterns {
            if let date = parseWithRegex(pattern: pattern, text: text) {
                return date
            }
        }
        
        return nil
    }
    
    private static func parseWithRegex(pattern: String, text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: text) {
                let matchedText = String(text[range])
                
                // Try different date parsing approaches
                if let date = parseDDMMYYYY(from: matchedText) {
                    return date
                } else if let date = parseExpMMMyyyy(from: matchedText) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Format-specific parsing methods
    
    /// Parse EXP MMM YYYY format (e.g., "EXP NOV 2027", "EXPIRES JAN 2025")
    private static func parseExpMMMyyyy(from text: String) -> Date? {
        // Regex to match EXP/EXPIRES followed by month and year
        let expPatterns = [
            #"(?:EXP|EXPIRES?)\s*([A-Z]{3})\s*(\d{4})"#,
            #"([A-Z]{3})\s*(\d{4})"#,  // Just month year without EXP prefix
            #"(\d{1,2})\s*([A-Z]{3})\s*(\d{2,4})"# // Day month year
        ]
        
        for pattern in expPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let components = matchedText.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty && !$0.contains("EXP") }
                
                if components.count == 2 {
                    let monthStr = components[0]
                    let yearStr = components[1]
                    
                    if let month = parseMonth(from: monthStr),
                       let year = Int(yearStr) {
                        return createDate(day: 1, month: month, year: adjustYear(year))
                    }
                } else if components.count == 3 {
                    // Day month year format
                    let dayStr = components[0]
                    let monthStr = components[1]
                    let yearStr = components[2]
                    
                    if let day = Int(dayStr),
                       let month = parseMonth(from: monthStr),
                       let year = Int(yearStr) {
                        return createDate(day: day, month: month, year: adjustYear(year))
                    }
                }
            }
        }
        return nil
    }
    
    /// Parse DD/MM/YYYY format (e.g., "15/11/2025")
    private static func parseDDMMYYYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})[\/](\d{1,2})[\/](\d{2,4})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "/")
            
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let year = Int(components[2]) {
                return createDate(day: day, month: month, year: adjustYear(year))
            }
        }
        return nil
    }
    
    /// Parse DD-MM-YY format (e.g., "15-11-25")
    private static func parseDDMMYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})[\-](\d{1,2})[\-](\d{2})"#
        
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedText = String(text[match])
            let components = matchedText.components(separatedBy: "-")
            
            if components.count == 3,
               let day = Int(components[0]),
               let month = Int(components[1]),
               let yearTwoDigit = Int(components[2]) {
                
                let year = adjustYear(yearTwoDigit)
                return createDate(day: day, month: month, year: year)
            }
        }
        return nil
    }
    
    /// Parse MM/YYYY format (e.g., "11/2025")
    private static func parseMMYYYY(from text: String) -> Date? {
        let pattern = #"(\d{1,2})[\/](\d{4})"#
        
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
    
    /// Parse spaced date formats (e.g., "15 11 25", "NOV 2027")
    private static func parseSpacedDate(from text: String) -> Date? {
        let patterns = [
            #"(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})"#,  // DD MM YYYY
            #"([A-Z]{3})\s+(\d{2,4})"#,              // MMM YYYY
            #"(\d{1,2})\s+([A-Z]{3})\s+(\d{2,4})"#   // DD MMM YYYY
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let components = matchedText.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                if components.count == 2 {
                    // MMM YYYY format
                    if let month = parseMonth(from: components[0]),
                       let year = Int(components[1]) {
                        return createDate(day: 1, month: month, year: adjustYear(year))
                    }
                } else if components.count == 3 {
                    // DD MM YYYY or DD MMM YYYY
                    if let day = Int(components[0]),
                       let month = parseMonth(from: components[1]) ?? Int(components[1]),
                       let year = Int(components[2]) {
                        return createDate(day: day, month: month, year: adjustYear(year))
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Parse dotted date formats (e.g., "15.11.2025")
    private static func parseDottedDate(from text: String) -> Date? {
        let patterns = [
            #"(\d{1,2})\.(\d{1,2})\.(\d{2,4})"#,  // DD.MM.YYYY
            #"(\d{4})\.(\d{1,2})"#                // YYYY.MM
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let components = matchedText.components(separatedBy: ".")
                
                if components.count == 3 {
                    // DD.MM.YYYY
                    if let day = Int(components[0]),
                       let month = Int(components[1]),
                       let year = Int(components[2]) {
                        return createDate(day: day, month: month, year: adjustYear(year))
                    }
                } else if components.count == 2 {
                    // YYYY.MM
                    if let year = Int(components[0]),
                       let month = Int(components[1]) {
                        return createDate(day: 1, month: month, year: year)
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Parse MMYY format (e.g., "1127" for Nov 2027)
    private static func parseMMYY(from text: String) -> Date? {
        // Look for 4-digit patterns that could be MMYY
        let pattern = #"\b(\d{4})\b"#
        
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
                        
                        let year = adjustYear(yearTwoDigit)
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
    
    /// Create a valid date from components
    private static func createDate(day: Int, month: Int, year: Int) -> Date? {
        guard isValidDate(day: day, month: month, year: year) else {
            print("❌ Invalid date components: \(day)/\(month)/\(year)")
            return nil
        }
        
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        let date = Calendar.current.date(from: components)
        print("✅ Created date: \(date?.description ?? "nil") from \(day)/\(month)/\(year)")
        return date
    }
    
    /// Validate date components
    private static func isValidDate(day: Int, month: Int, year: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return day >= 1 && day <= 31 && 
               month >= 1 && month <= 12 && 
               year >= currentYear && year <= currentYear + 20
    }
    
    /// Adjust 2-digit year to 4-digit year
    private static func adjustYear(_ year: Int) -> Int {
        if year < 100 {
            // Convert 2-digit year to 4-digit (assume 20xx for years 00-99)
            return year < 50 ? 2000 + year : 1900 + year
        }
        return year
    }
} 