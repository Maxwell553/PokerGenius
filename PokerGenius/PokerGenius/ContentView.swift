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
    @State private var communityCards: [Card] = Array(repeating: Card(rank: "", suit: ""), count: 5)
    
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
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCardEntry) {
                CardEntryView(communityCards: $communityCards)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CustomCameraView(communityCards: $communityCards, showCardEntry: $showCardEntry, isPresented: $showCamera)
            }
        }
    }
}

struct CardEntryView: View {
    @Binding var communityCards: [Card]
    @State private var holeCards: [Card] = [Card(rank: "", suit: ""), Card(rank: "", suit: "")]
    @State private var equity: Double?
    @State private var errorMessage: String?
    @State private var isCalculating = false
    
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
                .disabled(!areHoleCardsValid() || hasDuplicateCards() || isCalculating)
                
                if isCalculating {
                    HStack {
                        Text("Calculating")
                        AnimatedEllipsis()
                    }
                    .foregroundColor(.blue)
                }
                
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
        
        isCalculating = true
        errorMessage = nil
        equity = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try PokerHand.calculateEquity(holeCards: validHoleCards, communityCards: validCommunityCards) * 100
                DispatchQueue.main.async {
                    self.equity = result
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
