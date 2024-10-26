//
//  ContentView.swift
//  PokerGenius
//
//  Created by Max Ingargiola on 10/26/24.
//

import SwiftUI

struct ContentView: View {
    @State private var showCardEntry = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("PokerGenius")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Button("Calculate Hand Equity") {
                    showCardEntry = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCardEntry) {
                CardEntryView()
            }
        }
    }
}

struct CardEntryView: View {
    @State private var holeCards: [Card] = [Card(rank: "", suit: ""), Card(rank: "", suit: "")]
    @State private var communityCards: [Card] = Array(repeating: Card(rank: "", suit: ""), count: 5)
    @State private var equity: Double?
    @State private var errorMessage: String?
    
    let ranks = ["", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
    
    var body: some View {
        NavigationView {
            Form {
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
                
                if hasDuplicateCards() {
                    Text("Duplicate cards detected")
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                Button("Calculate Equity") {
                    calculateEquity()
                }
                .disabled(!areHoleCardsValid() || hasDuplicateCards())
                
                if let equity = equity {
                    Text("Equity: \(equity, specifier: "%.2f")%")
                        .font(.headline)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Enter Cards")
        }
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
        
        do {
            equity = try PokerHand.calculateEquity(holeCards: validHoleCards, communityCards: validCommunityCards) * 100
            errorMessage = nil
        } catch PokerError.invalidCardCount {
            errorMessage = "Please enter 2 hole cards and 0, 3, 4, or 5 community cards."
            equity = nil
        } catch PokerError.duplicateCards {
            errorMessage = "Duplicate cards detected. Please ensure all cards are unique."
            equity = nil
        } catch {
            errorMessage = "An unexpected error occurred."
            equity = nil
        }
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

#Preview {
    ContentView()
}
