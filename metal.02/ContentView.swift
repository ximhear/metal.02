//
//  ContentView.swift
//  metal.01
//
//  Created by gzonelee on 9/10/25.
//

import SwiftUI

struct ContentView: View {
    @State private var projectionMode: MetalView.ProjectionMode = .perspective
    @State private var showDebugInfo: Bool = false
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                MetalView(projectionMode: $projectionMode, showDebugInfo: $showDebugInfo)
                    .ignoresSafeArea()
                
                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Metal Debug Info")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Projection: \(projectionMode == .perspective ? "Perspective" : "Orthographic")")
                            .font(.caption2)
                        Text("Vertices: 3 (Triangle)")
                            .font(.caption2)
                    }
                    .padding(8)
                    .background(.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                }
            }
            
            VStack(spacing: 12) {
                Picker("Projection", selection: $projectionMode) {
                    Text("Perspective").tag(MetalView.ProjectionMode.perspective)
                    Text("Orthographic").tag(MetalView.ProjectionMode.orthographic)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Show Debug Info", isOn: $showDebugInfo)
                    .toggleStyle(SwitchToggleStyle())
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
