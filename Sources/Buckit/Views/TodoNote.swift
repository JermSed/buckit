import SwiftUI

// MARK: - Quick todo

struct TodoSection: View {
    @Environment(Store.self) private var store
    let space: Space
    @State private var draft = ""

    var body: some View {
        SectionLabel("To do") {
            if space.todos.contains(where: \.done) {
                Button("Clear done") { store.clearCompleted(in: space.id) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
            }
        }

        ForEach(space.todos) { todo in
            TodoRow(todo: todo, spaceID: space.id)
        }

        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
                .frame(width: 14)
            TextField("", text: $draft, prompt: Text("Add a to-do").foregroundColor(Theme.tertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.primary)
                .onSubmit {
                    store.addTodo(draft, to: space.id)
                    draft = ""
                }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
    }
}

private struct TodoRow: View {
    @Environment(Store.self) private var store
    let todo: Todo
    let spaceID: UUID
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleTodo(todo, in: spaceID) } label: {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(todo.done ? Theme.success.opacity(0.85) : Theme.tertiary)
                    .frame(width: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(todo.text)
                .font(.system(size: 13))
                .strikethrough(todo.done, color: Theme.tertiary)
                .foregroundStyle(todo.done ? Theme.tertiary : Theme.primary)
                .lineLimit(1)

            Spacer()

            if hovering {
                Button { store.removeTodo(todo, in: spaceID) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: Theme.rowRadius).fill(hovering ? Theme.hover : .clear))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onTapGesture { store.toggleTodo(todo, in: spaceID) }
        .contextMenu {
            Button(todo.done ? "Mark as Not Done" : "Mark as Done") { store.toggleTodo(todo, in: spaceID) }
            Button("Delete", role: .destructive) { store.removeTodo(todo, in: spaceID) }
        }
    }
}

// MARK: - Quick note

struct NoteSection: View {
    @Environment(Store.self) private var store
    let space: Space

    var body: some View {
        SectionLabel("Note")

        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(
                get: { space.note },
                set: { store.setNote($0, in: space.id) }
            ))
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.primary)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .padding(.horizontal, 5)
            .padding(.vertical, 6)

            if space.note.isEmpty {
                Text("Jot something down…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 76)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.note.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.note.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }
}
