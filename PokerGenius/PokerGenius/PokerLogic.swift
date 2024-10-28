import Foundation

class PokerHand {
    static let ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
    static let suits = ["♠", "♥", "♦", "♣"]
    
    static func calculateEquity(holeCards: [Card], communityCards: [Card]) throws -> Double {
        guard holeCards.count == 2 && (communityCards.count == 0 || communityCards.count == 3 || communityCards.count == 4 || communityCards.count == 5) else {
            throw PokerError.invalidCardCount
        }
        
        let allCards = holeCards + communityCards
        if hasDuplicates(allCards) {
            throw PokerError.duplicateCards
        }
        
        var wins = 0
        let deck = generateDeck().filter { !allCards.contains($0) }
        let simulations = 15000
        
        for _ in 0..<simulations {
            var simulationCommunityCards = communityCards
            var simulationDeck = deck
            
            // Complete the community cards if necessary
            while simulationCommunityCards.count < 5 {
                let randomCard = simulationDeck.remove(at: Int.random(in: 0..<simulationDeck.count))
                simulationCommunityCards.append(randomCard)
            }
            
            // Generate opponent's hand
            let opponentHoleCards = [
                simulationDeck.remove(at: Int.random(in: 0..<simulationDeck.count)),
                simulationDeck.remove(at: Int.random(in: 0..<simulationDeck.count))
            ]
            
            if evaluateHand(holeCards + simulationCommunityCards) > evaluateHand(opponentHoleCards + simulationCommunityCards) {
                wins += 1
            }
        }
        
        return Double(wins) / Double(simulations)
    }
    
    private static func generateDeck() -> [Card] {
        var deck: [Card] = []
        for rank in ranks {
            for suit in suits {
                deck.append(Card(rank: rank, suit: suit))
            }
        }
        return deck
    }
    
    private static func evaluateHand(_ cards: [Card]) -> Int {
        let sortedCards = cards.sorted { rankValue($0.rank) > rankValue($1.rank) }
        let ranks = sortedCards.map { $0.rank }
        let suits = sortedCards.map { $0.suit }
        
        // Check for Royal Flush (highest possible hand)
        let royalRanks = ["A", "K", "Q", "J", "10"]
        for suit in suits {
            let suitedCards = sortedCards.filter { $0.suit == suit }
            if suitedCards.count >= 5 {
                let suitedRanks = suitedCards.map { $0.rank }
                if royalRanks.allSatisfy({ suitedRanks.contains($0) }) {
                    return 10000  // Highest possible score
                }
            }
        }
        
        // Check for Straight Flush
        for suit in suits {
            let suitedCards = sortedCards.filter { $0.suit == suit }
            if suitedCards.count >= 5 {
                if let straightHighCard = checkForStraight(suitedCards.map { $0.rank }) {
                    return 9000 + rankValue(straightHighCard)
                }
            }
        }
        
        // Count rank occurrences
        var rankCounts: [String: Int] = [:]
        for rank in ranks {
            rankCounts[rank, default: 0] += 1
        }
        
        let sortedCounts = rankCounts.sorted { 
            $0.value > $1.value || ($0.value == $1.value && rankValue($0.key) > rankValue($1.key)) 
        }
        
        // Check for Four of a Kind
        if sortedCounts[0].value == 4 {
            return 8000 + rankValue(sortedCounts[0].key)
        }
        
        // Check for Full House
        if sortedCounts[0].value == 3 && sortedCounts[1].value >= 2 {
            return 7000 + rankValue(sortedCounts[0].key) * 13 + rankValue(sortedCounts[1].key)
        }
        
        // Check for Flush
        for suit in suits {
            let suitedCards = sortedCards.filter { $0.suit == suit }
            if suitedCards.count >= 5 {
                return 6000 + rankValue(suitedCards[0].rank)
            }
        }
        
        // Check for Straight
        if let straightHighCard = checkForStraight(ranks) {
            return 5000 + rankValue(straightHighCard)
        }
        
        // Check for Three of a Kind
        if sortedCounts[0].value == 3 {
            return 4000 + rankValue(sortedCounts[0].key)
        }
        
        // Check for Two Pair
        if sortedCounts[0].value == 2 && sortedCounts[1].value == 2 {
            return 3000 + max(rankValue(sortedCounts[0].key), rankValue(sortedCounts[1].key)) * 13 
                + min(rankValue(sortedCounts[0].key), rankValue(sortedCounts[1].key))
        }
        
        // Check for One Pair
        if sortedCounts[0].value == 2 {
            return 2000 + rankValue(sortedCounts[0].key)
        }
        
        // High Card
        return 1000 + rankValue(ranks[0])
    }
    
    private static func rankValue(_ rank: String) -> Int {
        return ranks.firstIndex(of: rank)!
    }
    
    private static func checkForStraight(_ ranks: [String]) -> String? {
        let uniqueRanks = Array(Set(ranks)).sorted { rankValue($0) > rankValue($1) }
        if uniqueRanks.count < 5 { return nil }
        
        // Check for Ace-low straight (A,2,3,4,5)
        if ranks.contains("A") {
            let lowStraight = ["5", "4", "3", "2", "A"]
            if lowStraight.allSatisfy({ ranks.contains($0) }) {
                return "5"
            }
        }
        
        // Check for regular straights
        for i in 0...(uniqueRanks.count - 5) {
            let possibleStraight = uniqueRanks[i...(i+4)]
            let values = possibleStraight.map { rankValue($0) }
            if values[0] - values[4] == 4 {
                return uniqueRanks[i]
            }
        }
        
        return nil
    }
    
    static func hasDuplicates(_ cards: [Card]) -> Bool {
        var seenCards: Set<String> = []
        for card in cards where card.rank != "" && card.suit != "" {
            let cardString = "\(card.rank)\(card.suit)"
            if seenCards.contains(cardString) {
                return true
            }
            seenCards.insert(cardString)
        }
        return false
    }
}

enum PokerError: Error {
    case invalidCardCount
    case duplicateCards
}
