import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddInvoice = false
    @State private var showingManagement = false
    @State private var editingInvoice: Invoice? = nil
    @State private var refreshID = UUID()
    
    // 判断是否为 iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("开票信息")
                    .font(.headline)
                
                Spacer()
                
                if isIPad {
                    Button(action: { showingManagement = true }) {
                        Label("管理", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.accentColor)
                    }
                } else {
                NavigationLink(destination: InvoiceManagementView(project: $project).environmentObject(projectStore)) {
                    Label("管理", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { showingAddInvoice = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            if !project.invoices.isEmpty {
                List {
                    ForEach(project.invoices.indices, id: \ .self) { index in
                        InvoiceRow(invoice: $project.invoices[index], project: project)
                            .environmentObject(projectStore)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                editingInvoice = project.invoices[index]
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(project.invoices.count) * 90, 270)) // 限制最大高度
                .background(Color.clear)
                .scrollContentBackground(.hidden)
            } else {
                Text("暂无开票信息")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .id(refreshID)
        .onChange(of: project.invoices) { _ in
            refreshID = UUID()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingAddInvoice) {
            AddInvoiceView(project: project)
                .environmentObject(projectStore)
                .onDisappear {
                    refreshID = UUID()
                }
        }
        .sheet(isPresented: $showingManagement) {
            NavigationView {
                InvoiceManagementView(project: $project)
                    .environmentObject(projectStore)
            }
        }
        .sheet(item: $editingInvoice) { invoice in
            if let index = project.invoices.firstIndex(where: { $0.id == invoice.id }) {
                EditInvoiceView(invoice: $project.invoices[index], project: project, isPresented: Binding(get: { editingInvoice != nil }, set: { if !$0 { editingInvoice = nil } }))
            .environmentObject(projectStore)
                    .onDisappear {
                        refreshID = UUID()
                    }
            }
        }
    }
} 