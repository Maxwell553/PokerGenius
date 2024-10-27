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
        
        // Check for flush
        if suits.filter({ $0 == suits[0] }).count >= 5 {
            return 6000 + rankValue(ranks[0])
        }
        
        // Check for straight
        var straightCount = 1
        var straightHighCard = ranks[0]
        for i in 1..<ranks.count {
            if rankValue(ranks[i]) == rankValue(ranks[i-1]) - 1 {
                straightCount += 1
                if straightCount == 5 {
                    return 5000 + rankValue(straightHighCard)
                }
            } else if rankValue(ranks[i]) != rankValue(ranks[i-1]) {
                straightCount = 1
                straightHighCard = ranks[i]
            }
        }
        
        // Count rank occurrences
        var rankCounts: [String: Int] = [:]
        for rank in ranks {
            rankCounts[rank, default: 0] += 1
        }
        
        let sortedCounts = rankCounts.sorted { $0.value > $1.value || ($0.value == $1.value && rankValue($0.key) > rankValue($1.key)) }
        
        // Check for four of a kind
        if sortedCounts[0].value == 4 {
            return 7000 + rankValue(sortedCounts[0].key)
        }
        
        // Check for full house
        if sortedCounts[0].value == 3 && sortedCounts[1].value >= 2 {
            return 6000 + rankValue(sortedCounts[0].key) * 13 + rankValue(sortedCounts[1].key)
        }
        
        // Check for three of a kind
        if sortedCounts[0].value == 3 {
            return 4000 + rankValue(sortedCounts[0].key)
        }
        
        // Check for two pair
        if sortedCounts[0].value == 2 && sortedCounts[1].value == 2 {
            return 3000 + max(rankValue(sortedCounts[0].key), rankValue(sortedCounts[1].key)) * 13 + min(rankValue(sortedCounts[0].key), rankValue(sortedCounts[1].key))
        }
        
        // Check for one pair
        if sortedCounts[0].value == 2 {
            return 2000 + rankValue(sortedCounts[0].key)
        }
        
        // High card
        return 1000 + rankValue(ranks[0])
    }
    
    private static func rankValue(_ rank: String) -> Int {
        return ranks.firstIndex(of: rank)!
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
