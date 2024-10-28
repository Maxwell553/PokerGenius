//
//  ContentView.swift
//  PokerGenius
//
//  Created by Max Ingargiola on 10/26/24.
//

import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @State private var showCardEntry = false
    @State private var showCamera = false
    @State private var showCameraInfo = false
    @State private var communityCards: [Card] = Array(repeating: Card(rank: "", suit: ""), count: 5)
    @State private var holeCards: [Card] = [Card(rank: "", suit: ""), Card(rank: "", suit: "")]  // Lifted up state
    
    var body: some View {
        NavigationView {
            VStack {
                Text("PokerGenius")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                HStack {
                    Button("Calculate Hand Equity") {
                        showCardEntry = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            showCamera = true
                        }) {
                            Image(systemName: "camera")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            showCameraInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        .alert("Camera Feature", isPresented: $showCameraInfo) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("The camera feature allows you to automatically input cards by taking a photo. This feature is still in development and may not always recognize cards accurately.")
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCardEntry) {
                CardEntryView(
                    communityCards: $communityCards,
                    holeCards: $holeCards  // Pass the binding
                )
            }
            .fullScreenCover(isPresented: $showCamera) {
                CustomCameraView(
                    communityCards: $communityCards,
                    showCardEntry: $showCardEntry,
                    isPresented: $showCamera
                )
            }
        }
    }
}

struct CardEntryView: View {
    @Binding var communityCards: [Card]
    @Binding var holeCards: [Card]  // Changed from @State to @Binding
    @State private var equity: Double?
    @State private var errorMessage: String?
    @State private var isCalculating = false
    @State private var equityExplanation: String = ""
    @State private var showingEquityInfo = false
    @Environment(\.dismiss) var dismiss
    
    let ranks = ["", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
    
    var body: some View {
        NavigationView {
            Form {
                Group {
                    Section(header: Text("Community Cards")) {
                        ForEach(0..<5) { index in
                            CardPickerView(card: $communityCards[index], ranks: ranks)
                        }
                    }
                    
                    Section(header: Text("Hole Cards")) {
                        ForEach(0..<2) { index in
                            CardPickerView(card: $holeCards[index], ranks: ranks)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                
                Section(header: Text("Best Hand")) {
                    if let bestHand = evaluateBestHand() {
                        Text(bestHand)
                            .font(.headline)
                    }
                }
                
                if hasDuplicateCards() {
                    Text("Duplicate cards detected")
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                Button("Calculate Equity") {
                    calculateEquity()
                }
                .disabled(!areHoleCardsValid() || hasDuplicateCards() || isCalculating)
                
                Button(action: resetHand) {
                    Text("Reset Hand")
                        .foregroundColor(.red)
                }
                
                if isCalculating {
                    HStack {
                        Text("Calculating")
                        AnimatedEllipsis()
                    }
                    .foregroundColor(.blue)
                }
                
                if let equity = equity {
                    HStack {
                        Text("Equity: \(equity, specifier: "%.2f")%")
                            .font(.headline)
                        
                        Button(action: { showingEquityInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                        .popover(isPresented: $showingEquityInfo) {
                            ScrollView {
                                Text(equityExplanation)
                                    .padding()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: 300)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Enter Cards")
            .navigationBarItems(trailing: Button("Done") {
                // Simply dismiss the view without resetting any values
                dismiss()
            })
            // Remove any .onDisappear or similar modifiers that might reset values
        }
    }
    
    private func resetHand() {
        communityCards = Array(repeating: Card(rank: "", suit: ""), count: 5)
        holeCards = [Card(rank: "", suit: ""), Card(rank: "", suit: "")]
        equity = nil
        errorMessage = nil
        isCalculating = false
        equityExplanation = ""
    }
    
    private func areHoleCardsValid() -> Bool {
        let validHoleCards = holeCards.filter { $0.rank != "" && $0.suit != "" }
        return validHoleCards.count == 2
    }
    
    private func hasDuplicateCards() -> Bool {
        let allCards = holeCards + communityCards
        return PokerHand.hasDuplicates(allCards)
    }
    
    private func calculateEquity() {
        let validHoleCards = holeCards.filter { $0.rank != "" && $0.suit != "" }
        let validCommunityCards = communityCards.filter { $0.rank != "" && $0.suit != "" }
        
        isCalculating = true
        errorMessage = nil
        equity = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try PokerHand.calculateEquity(holeCards: validHoleCards, communityCards: validCommunityCards) * 100
                DispatchQueue.main.async {
                    self.equity = result
                    self.equityExplanation = generateEquityExplanation(holeCards: validHoleCards, communityCards: validCommunityCards, equity: result)
                    self.isCalculating = false
                }
            } catch PokerError.invalidCardCount {
                DispatchQueue.main.async {
                    self.errorMessage = "Please enter 2 hole cards and 0, 3, 4, or 5 community cards."
                    self.isCalculating = false
                }
            } catch PokerError.duplicateCards {
                DispatchQueue.main.async {
                    self.errorMessage = "Duplicate cards detected. Please ensure all cards are unique."
                    self.isCalculating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "An unexpected error occurred."
                    self.isCalculating = false
                }
            }
        }
    }
    
    private func generateEquityExplanation(holeCards: [Card], communityCards: [Card], equity: Double) -> String {
        var explanation = "Your hand: \(describeCards(holeCards))\n\n"
        
        let validCommunityCards = communityCards.filter { $0.rank != "" && $0.suit != "" }
        
        if validCommunityCards.isEmpty {
            explanation += "Please input community cards for more accurate hand analysis and possible opponent holdings.\n\n"
            explanation += "With this hand, you have a \(String(format: "%.1f", equity))% chance of winning against a random hand.\n"
            return explanation
        }
        
        explanation += "Community cards: \(describeCards(validCommunityCards))\n\n"
        
        if let bestHand = evaluateBestHand() {
            explanation += "Current best hand: \(bestHand)\n\n"
            
            // Add possible opponent hands that could beat you
            let possibleBeatingHands = findPossibleBeatingHands(currentHand: bestHand, communityCards: validCommunityCards)
            if possibleBeatingHands.isEmpty && equity == 100.0 {
                explanation += "No possible hands can beat yours - you have the nuts!\n\n"
            } else if possibleBeatingHands.isEmpty {
                explanation += "You have a very strong hand.\n\n"
            } else {
                explanation += "Opponent hands that could beat you:\n"
                for hand in possibleBeatingHands.prefix(3) {
                    explanation += "• \(hand)\n"
                }
                explanation += "\n"
            }
        }
        
        explanation += "With this hand, you have a \(String(format: "%.1f", equity))% chance of winning.\n\n"
        
        // Add potential hand possibilities only if there are community cards
        if !validCommunityCards.isEmpty {
            let possibleHands = analyzePossibleHands(holeCards: holeCards, communityCards: validCommunityCards)
            explanation += "Possible improvements:\n"
            explanation += possibleHands
        }
        
        return explanation
    }
    
    private func findPossibleBeatingHands(currentHand: String, communityCards: [Card]) -> [String] {
        var beatingHands: [String] = []
        let validCommunityCards = communityCards.filter { $0.rank != "" && $0.suit != "" }
        
        // Define hand rankings
        let handRankings = [
            "Royal Flush",
            "Straight Flush",
            "Four of a Kind",
            "Full House",
            "Flush",
            "Straight",
            "Three of a Kind",
            "Two Pair",
            "One Pair",
            "High Card"
        ]
        
        // Find current hand rank
        let currentHandRank = handRankings.firstIndex { currentHand.starts(with: $0) } ?? 0
        
        // Get available ranks and suits (not in community cards)
        let availableRanks = ranks.filter { rank in
            rank != "" && !validCommunityCards.contains { $0.rank == rank }
        }
        
        // Check for paired board
        let boardPairs = Dictionary(grouping: validCommunityCards, by: { $0.rank })
            .filter { $0.value.count >= 2 }
        
        // Check for suited board
        let boardSuits = Dictionary(grouping: validCommunityCards, by: { $0.suit })
            .filter { $0.value.count >= 3 }
        
        if !currentHand.starts(with: "Royal Flush") {
            // For paired board
            for (rank, cards) in boardPairs {
                if cards.count == 2 {
                    // If board has a pair, suggest specific pocket pairs that make a higher three of a kind
                    for higherRank in availableRanks.filter({ rankValue($0) > rankValue(rank) }) {
                        beatingHands.append("Pocket \(higherRank)\(higherRank) for a higher three of a kind")
                    }
                }
            }
            
            // For suited board
            for (suit, cards) in boardSuits {
                if cards.count >= 3 {
                    let suitedRanks = cards.map { $0.rank }
                    let highestBoardRank = suitedRanks.max(by: { rankValue($0) < rankValue($1) }) ?? ""
                    
                    // Suggest specific suited cards that would make a higher flush
                    for rank in availableRanks.filter({ rankValue($0) > rankValue(highestBoardRank) }) {
                        beatingHands.append("\(rank)\(suit) + any \(suit) for a higher flush")
                    }
                }
            }
            
            // For straight possibilities
            if let straightInfo = checkSpecificStraightPossibilities(communityCards: validCommunityCards) {
                beatingHands.append(straightInfo)
            }
            
            // For high card or one pair boards
            if validCommunityCards.count >= 3 && boardPairs.isEmpty {
                let highestBoardRank = validCommunityCards.map { $0.rank }
                    .max(by: { rankValue($0) < rankValue($1) }) ?? ""
                
                // Suggest specific pocket pairs above the board
                for rank in availableRanks.filter({ rankValue($0) > rankValue(highestBoardRank) }) {
                    beatingHands.append("Pocket \(rank)s for a higher pair")
                }
            }
        }
        
        return beatingHands.prefix(3).map { $0 }
    }
    
    private func checkSpecificStraightPossibilities(communityCards: [Card]) -> String? {
        let boardRanks = communityCards.map { $0.rank }
        let rankValues = boardRanks.compactMap { ranks.firstIndex(of: $0) }
        
        if rankValues.count >= 3 {
            let sortedValues = rankValues.sorted()
            if sortedValues.last! - sortedValues.first! <= 4 {
                // Find the missing ranks needed for a straight
                let neededRanks = findMissingStraightRanks(sortedValues)
                if !neededRanks.isEmpty {
                    return "Hole cards \(neededRanks.joined(separator: " and ")) would complete a straight"
                }
            }
        }
        return nil
    }
    
    private func findMissingStraightRanks(_ values: [Int]) -> [String] {
        let allPossibleValues = Set(values[0]...values[0]+4)
        let missingValues = allPossibleValues.subtracting(values)
        return missingValues.map { ranks[$0] }
    }
    
    private func rankValue(_ rank: String) -> Int {
        return ranks.firstIndex(of: rank) ?? 0
    }
    
    private func describeCards(_ cards: [Card]) -> String {
        return cards.filter { $0.rank != "" && $0.suit != "" }
            .map { "\($0.rank)\($0.suit)" }
            .joined(separator: " ")
    }
    
    private func analyzePossibleHands(holeCards: [Card], communityCards: [Card]) -> String {
        var analysis = ""
        let allCards = holeCards + communityCards
        
        // Check for flush draw
        let suitCounts = Dictionary(grouping: allCards, by: { $0.suit })
        for (suit, cards) in suitCounts where cards.count == 4 {
            analysis += "• One card away from a flush in \(suit)\n"
        }
        
        // Check for straight draw
        let ranks = allCards.map { $0.rank }
        if isOpenEndedStraightDraw(ranks) {
            analysis += "• Open-ended straight draw\n"
        }
        
        // Add more specific analysis based on the current hand
        if let bestHand = evaluateBestHand() {
            if bestHand.contains("Pair") {
                analysis += "• Potential to improve to three of a kind or two pair\n"
            } else if bestHand.contains("High Card") {
                analysis += "• Potential to pair up with any matching card\n"
            }
        }
        
        return analysis.isEmpty ? "No clear drawing opportunities" : analysis
    }
    
    private func isOpenEndedStraightDraw(_ ranks: [String]) -> Bool {
        let rankValues = ranks.compactMap { ranks.firstIndex(of: $0) }
        let sortedValues = Array(Set(rankValues)).sorted()
        
        if sortedValues.count < 4 { return false }
        
        for i in 0...(sortedValues.count - 4) {
            if sortedValues[i+3] - sortedValues[i] == 3 {
                return true
            }
        }
        return false
    }
    
    private func evaluateBestHand() -> String? {
        let validHoleCards = holeCards.filter { $0.rank != "" && $0.suit != "" }
        let validCommunityCards = communityCards.filter { $0.rank != "" && $0.suit != "" }
        
        if validHoleCards.isEmpty {
            return nil
        }
        
        let allCards = validHoleCards + validCommunityCards
        if allCards.count < 2 {
            return nil
        }
        
        // Check for Royal Flush
        if hasRoyalFlush(allCards) {
            return "Royal Flush"
        }
        
        // Check for Straight Flush
        if let highCard = hasStraightFlush(allCards) {
            return "Straight Flush (\(highCard) high)"
        }
        
        // Check for Four of a Kind
        if let rank = hasFourOfAKind(allCards) {
            return "Four of a Kind (\(rank)s)"
        }
        
        // Check for Full House
        if let (three, pair) = hasFullHouse(allCards) {
            return "Full House (\(three)s full of \(pair)s)"
        }
        
        // Check for Flush
        if let suit = hasFlush(allCards) {
            return "Flush (\(suit))"
        }
        
        // Check for Straight
        if let highCard = hasStraight(allCards) {
            return "Straight (\(highCard) high)"
        }
        
        // Check for Three of a Kind
        if let rank = hasThreeOfAKind(allCards) {
            return "Three of a Kind (\(rank)s)"
        }
        
        // Check for Two Pair
        if let (high, low) = hasTwoPair(allCards) {
            return "Two Pair (\(high)s and \(low)s)"
        }
        
        // Check for One Pair
        if let rank = hasOnePair(allCards) {
            return "One Pair (\(rank)s)"
        }
        
        // High Card
        if let highCard = getHighCard(allCards) {
            return "High Card (\(highCard))"
        }
        
        return nil
    }
    
    private func hasRoyalFlush(_ cards: [Card]) -> Bool {
        let royalRanks = ["10", "J", "Q", "K", "A"]
        for suit in ["♠", "♥", "♦", "♣"] {
            let suitedCards = cards.filter { $0.suit == suit }
            if suitedCards.count >= 5 {
                let ranks = Set(suitedCards.map { $0.rank })
                if royalRanks.allSatisfy({ ranks.contains($0) }) {
                    return true
                }
            }
        }
        return false
    }
    
    private func hasStraightFlush(_ cards: [Card]) -> String? {
        for suit in ["♠", "♥", "♦", "♣"] {
            let suitedCards = cards.filter { $0.suit == suit }
            if let highCard = hasStraight(suitedCards) {
                return highCard
            }
        }
        return nil
    }
    
    private func hasFourOfAKind(_ cards: [Card]) -> String? {
        let rankCounts = Dictionary(grouping: cards, by: { $0.rank })
        return rankCounts.first { $0.value.count >= 4 }?.key
    }
    
    private func hasFullHouse(_ cards: [Card]) -> (String, String)? {
        let rankCounts = Dictionary(grouping: cards, by: { $0.rank })
        if let threeOfAKind = rankCounts.first(where: { $0.value.count >= 3 })?.key,
           let pair = rankCounts.first(where: { $0.key != threeOfAKind && $0.value.count >= 2 })?.key {
            return (threeOfAKind, pair)
        }
        return nil
    }
    
    private func hasFlush(_ cards: [Card]) -> String? {
        let suitCounts = Dictionary(grouping: cards, by: { $0.suit })
        return suitCounts.first { $0.value.count >= 5 }?.key
    }
    
    private func hasStraight(_ cards: [Card]) -> String? {
        let validCards = cards.filter { $0.rank != "" && $0.suit != "" }
        if validCards.isEmpty {
            return nil
        }
        
        let sortedRanks = validCards.map { $0.rank }
            .map { ranks.firstIndex(of: $0)! }
            .sorted(by: >)  // Sort in descending order
        
        if sortedRanks.isEmpty {
            return nil
        }
        
        var consecutiveCount = 1
        var currentHighCard = sortedRanks[0]
        
        for i in 1..<sortedRanks.count {
            if sortedRanks[i] == sortedRanks[i-1] - 1 {
                consecutiveCount += 1
                if consecutiveCount == 5 {
                    return ranks[currentHighCard]
                }
            } else if sortedRanks[i] != sortedRanks[i-1] {
                consecutiveCount = 1
                currentHighCard = sortedRanks[i]
            }
        }
        return nil
    }
    
    private func hasThreeOfAKind(_ cards: [Card]) -> String? {
        let rankCounts = Dictionary(grouping: cards, by: { $0.rank })
        return rankCounts.first { $0.value.count >= 3 }?.key
    }
    
    private func hasTwoPair(_ cards: [Card]) -> (String, String)? {
        let rankCounts = Dictionary(grouping: cards, by: { $0.rank })
            .filter { $0.value.count >= 2 }
            .sorted { ranks.firstIndex(of: $0.key)! > ranks.firstIndex(of: $1.key)! }
        
        if rankCounts.count >= 2 {
            return (rankCounts[0].key, rankCounts[1].key)
        }
        return nil
    }
    
    private func hasOnePair(_ cards: [Card]) -> String? {
        let rankCounts = Dictionary(grouping: cards, by: { $0.rank })
        return rankCounts.first { $0.value.count >= 2 }?.key
    }
    
    private func getHighCard(_ cards: [Card]) -> String? {
        return cards.max { a, b in
            ranks.firstIndex(of: a.rank)! < ranks.firstIndex(of: b.rank)!
        }?.rank
    }
}

struct CardPickerView: View {
    @Binding var card: Card
    let ranks: [String]
    let suits = ["", "♠", "♥", "♦", "♣"]
    
    var body: some View {
        HStack {
            Picker("Rank", selection: $card.rank) {
                ForEach(ranks, id: \.self) { rank in
                    Text(rank.isEmpty ? "Rank" : rank)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Picker("Suit", selection: $card.suit) {
                ForEach(suits, id: \.self) { suit in
                    Text(suit)
                        .foregroundColor(suitColor(suit))
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private func suitColor(_ suit: String) -> Color {
        switch suit {
        case "♥", "♦":
            return .red
        case "♠", "♣":
            return .black
        default:
            return .primary
        }
    }
}

struct Card: Identifiable, Equatable, Hashable {
    let id = UUID()
    var rank: String
    var suit: String
    
    var description: String {
        return "\(rank)\(suit)"
    }
}

struct CustomCameraView: View {
    @Binding var communityCards: [Card]
    @Binding var showCardEntry: Bool
    @Binding var isPresented: Bool
    @StateObject private var camera = CameraModel()
    @State private var capturedImage: UIImage?
    @State private var showingImageConfirmation = false
    @State private var recognitionStatus: RecognitionStatus = .idle
    @State private var showAlert = false
    @State private var chatGPTResponse: String?
    
    enum RecognitionStatus: Equatable {
        case idle
        case recognizing
        case success
        case failure(String)
    }
    
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        camera.takePicture()
                    }) {
                        Image(systemName: "camera")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
        .onAppear {
            camera.check()
        }
        .onChange(of: camera.photo) { oldValue, newPhoto in
            if let photo = newPhoto {
                capturedImage = photo
                showingImageConfirmation = true
            }
        }
        .sheet(isPresented: $showingImageConfirmation) {
            ImageConfirmationView(image: $capturedImage, onConfirm: {
                showingImageConfirmation = false
                isPresented = false // Close camera overlay
                recognizeCards()
            }, onRetake: {
                capturedImage = nil
                showingImageConfirmation = false
            })
        }
        .alert(isPresented: $showAlert) {
            switch recognitionStatus {
            case .recognizing:
                return Alert(title: Text("Recognizing cards..."))
            case .success:
                return Alert(title: Text("Recognition successful!"), message: Text(chatGPTResponse ?? ""), dismissButton: .default(Text("OK")) {
                    showCardEntry = true
                })
            case .failure(let error):
                return Alert(title: Text("Recognition failed"), message: Text(error), dismissButton: .default(Text("OK")))
            case .idle:
                return Alert(title: Text("")) // This case should never occur
            }
        }
    }
    
    private func recognizeCards() {
        guard let image = capturedImage else { return }
        
        recognitionStatus = .recognizing
        showAlert = true
        
        print("Debug: Sending image to ChatGPT")
        
        ChatGPTService.shared.analyzeImage(image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("Debug: Received response from ChatGPT: \(response)")
                    chatGPTResponse = response
                    let recognizedCards = parseRecognizedCards(from: response)
                    updateCommunityCards(with: recognizedCards)
                    recognitionStatus = .success
                    showAlert = true
                    // Automatically open the calculator window after recognition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCardEntry = true
                    }
                case .failure(let error):
                    print("Debug: Error received from ChatGPT: \(error.localizedDescription)")
                    recognitionStatus = .failure(error.localizedDescription)
                    showAlert = true
                }
            }
        }
    }
    
    private func parseRecognizedCards(from response: String) -> [Card] {
        let lines = response.components(separatedBy: .newlines)
        return lines.compactMap { line -> Card? in
            let components = line.lowercased().components(separatedBy: " of ")
            guard components.count == 2 else { return nil }
            let rank = parseRank(components[0].trimmingCharacters(in: .whitespaces))
            let suit = suitFromString(components[1].trimmingCharacters(in: .whitespaces))
            return Card(rank: rank, suit: suit)
        }
    }
    
    private func parseRank(_ rank: String) -> String {
        switch rank.lowercased() {
        case "ace": return "A"
        case "king": return "K"
        case "queen": return "Q"
        case "jack": return "J"
        default: return rank.capitalized
        }
    }
    
    private func suitFromString(_ suit: String) -> String {
        switch suit.lowercased() {
        case "spades": return "♠"
        case "hearts": return "♥"
        case "diamonds": return "♦"
        case "clubs": return "♣"
        default: return ""
        }
    }
    
    private func updateCommunityCards(with recognizedCards: [Card]) {
        for (index, card) in recognizedCards.enumerated() where index < 5 {
            communityCards[index] = card
        }
        print("Debug: Updated community cards: \(communityCards)")
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var photo: UIImage?
    
    func check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setUp()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
        }
    }
    
    func setUp() {
        do {
            self.session.beginConfiguration()
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            let input = try AVCaptureDeviceInput(device: device!)
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func takePicture() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            DispatchQueue.main.async {
                withAnimation { self.isTaken.toggle() }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) {
            self.photo = image
        } else {
            print("Error: \(error?.localizedDescription ?? "No error description")")
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        camera.session.startRunning()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct AnimatedEllipsis: View {
    @State private var dotCount = 0
    
    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    dotCount = (dotCount + 1) % 4
                }
            }
    }
}

struct ImageConfirmationView: View {
    @Binding var image: UIImage?
    let onConfirm: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
            
            HStack {
                Button(action: onRetake) {
                    Text("Retake")
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                Button(action: onConfirm) {
                    Text("Use Photo")
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
    }
}

#Preview {
    ContentView()
}
