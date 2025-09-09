//
//  ContentView.swift
//  metal.01
//
//  Created by gzonelee on 9/10/25.
//

import SwiftUI

struct ContentView: View {
    @State private var projectionMode: MetalView.ProjectionMode = .perspective
    
    var body: some View {
        VStack {
            MetalView(projectionMode: $projectionMode)
                .ignoresSafeArea()
            
            Picker("Projection", selection: $projectionMode) {
                Text("Perspective").tag(MetalView.ProjectionMode.perspective)
                Text("Orthographic").tag(MetalView.ProjectionMode.orthographic)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
