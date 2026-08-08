import SwiftData
import SwiftUI

struct ActiveSessionView: View {
    @Environment(SessionController.self) private var controller
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    let session: Session
    let restTimer: RestTimerController

    @State private var showingFinishConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingExercisePicker = false

    /// Handed the finish result so Session Complete can be presented.
    var onFinished: (FinishOutcome) -> Void = { _ in }
    /// Fires when a checked-off set should start the rest timer.
    var onRestRequested: (SessionExercise) -> Void = { _ in }

    private var formatter: UnitFormatter { settings.unitFormatter }

    var body: some View {
        @Bindable var controller = controller

        NavigationStack {
            List {
                Section { headerStats.listRowInsets(EdgeInsets()) }
                    .listRowBackground(Color.clear)

                ForEach(session.orderedExercises, id: \.persistentModelID) { entry in
                    exerciseSection(entry)
                }

                Section {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bottomAccessories }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    controller.addExercise(exercise, context: context)
                }
            }
            .confirmationDialog(
                "Finish session?",
                isPresented: $showingFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Finish", role: .confirm) { finish() }
                Button("Keep logging", role: .cancel) {}
            } message: {
                Text(finishMessage)
            }
            .alert("Discard session?", isPresented: $showingDiscardConfirmation) {
                Button("Discard", role: .destructive) { controller.discard(context: context) }
                Button("Keep logging", role: .cancel) {}
            } message: {
                Text("This session and everything logged in it will be deleted. This cannot be undone.")
            }
        }
    }

    // MARK: Header

    private var headerStats: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 0) {
                stat(title: "Elapsed", value: elapsedText)
                Divider().frame(height: 30)
                stat(title: "Volume", value: formatter.volumeString(kg: session.volumeKg))
                Divider().frame(height: 30)
                stat(title: "Sets", value: "\(session.completedSetCount)")
            }
            .padding(.vertical, 12)
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var elapsedText: String {
        DurationFormatting.clock(Date.now.timeIntervalSince(session.startedAt))
    }

    // MARK: Exercise section

    private func exerciseSection(_ entry: SessionExercise) -> some View {
        Section {
            ForEach(Array(entry.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                SetRowView(
                    setEntry: set,
                    index: index,
                    reference: controller.reference(for: entry, at: index)
                ) { shouldRest in
                    if shouldRest { onRestRequested(entry) }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        controller.duplicate(set, context: context)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        controller.delete(set, context: context)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                controller.addSet(to: entry, context: context)
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                Text(entry.displayName)
                Spacer()
                if let muscle = entry.exercise?.primaryMuscle.displayName {
                    Text(muscle)
                        .foregroundStyle(.tertiary)
                }
            }
        } footer: {
            let volume = entry.volumeKg
            if volume > 0 {
                Text("\(entry.completedSets.count) sets · \(formatter.volumeString(kg: volume))")
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                controller.dismissKeypad()
                controller.isPresented = false
            } label: {
                Label("Minimise", systemImage: "chevron.down")
            }
            .accessibilityLabel("Minimise session")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                Divider()
                Button(role: .destructive) {
                    showingDiscardConfirmation = true
                } label: {
                    Label("Discard session", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Finish") { showingFinishConfirmation = true }
                .fontWeight(.semibold)
        }
    }

    private var finishMessage: String {
        let sets = controller.uncheckedSetCount
        let exercises = controller.exercisesLosingAllSetsCount

        guard sets > 0 else {
            return "\(session.completedSetCount) sets logged."
        }
        var message = "\(sets) unchecked \(sets == 1 ? "set" : "sets") will be discarded."
        if exercises > 0 {
            message += " \(exercises) \(exercises == 1 ? "exercise" : "exercises") with no completed sets will be removed."
        }
        return message
    }

    private func finish() {
        do {
            let outcome = try controller.finish(context: context, settings: settings)
            onFinished(outcome)
        } catch {
            assertionFailure("Finishing failed: \(error)")
        }
    }

    // MARK: Keypad

    /// The rest bar sits above the keypad so both can be on screen at once — resting and
    /// correcting the set you just logged are not mutually exclusive.
    @ViewBuilder
    private var bottomAccessories: some View {
        VStack(spacing: 0) {
            if restTimer.isRunning {
                RestTimerBar(timer: restTimer)
            }
            keypad
        }
    }

    @ViewBuilder
    private var keypad: some View {
        if let target = controller.keypadTarget,
           let set = controller.focusedSet(in: session) {
            NumericKeypad(
                title: keypadTitle(target.field),
                displayText: controller.keypadDisplayText(for: set, field: target.field, formatter: formatter),
                unitLabel: target.field == .weight ? formatter.abbreviation : "",
                field: target.field,
                decimalSeparator: formatter.decimalSeparator,
                weightIncrements: formatter.weightIncrements,
                onIncrement: { controller.increment($0, on: set, field: target.field, formatter: formatter, context: context) },
                onDigit: { controller.appendDigit($0, to: set, field: target.field, formatter: formatter, context: context) },
                onBackspace: { controller.backspace(on: set, field: target.field, formatter: formatter, context: context) },
                onClear: { controller.clearField(on: set, field: target.field, formatter: formatter, context: context) },
                onNext: { controller.advanceKeypad() },
                onHide: { controller.dismissKeypad() }
            )
            .transition(.move(edge: .bottom))
        }
    }

    private func keypadTitle(_ field: KeypadField) -> String {
        switch field {
        case .weight: "Weight"
        case .reps: "Reps"
        case .duration: "Seconds"
        }
    }
}
