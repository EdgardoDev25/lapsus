import SwiftUI

/// Bienvenida de la primera vez. El último paso (horario) es opcional.
struct OnboardingView: View {
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var store: WorkStore
    @Environment(\.palette) private var pal

    @State private var page = 0
    @State private var draft = WorkSchedule.standard

    private let lastPage = 3

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < lastPage {
                    Button("Saltar") {
                        withAnimation(.easeInOut(duration: 0.3)) { page = lastPage }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.sub)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 22)

            TabView(selection: $page) {
                welcome.tag(0)
                gesture.tag(1)
                pauses.tag(2)
                schedulePage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: page)

            dots.padding(.vertical, 14)

            if page < lastPage {
                PrimaryButton(title: page == 0 ? "Comenzar" : "Siguiente", icon: nil) {
                    withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                    Haptics.tap()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            } else {
                VStack(spacing: 6) {
                    PrimaryButton(title: "Guardar horario y empezar", icon: "checkmark",
                                  enabled: draft.days.allSatisfy(\.isValid)) {
                        finish(saveSchedule: true)
                    }
                    Button("Ahora no, lo configuro después") { finish(saveSchedule: false) }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(pal.sub)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 4)
            }
        }
        .background(pal.bg.ignoresSafeArea())
        .onAppear { draft = prefs.s.schedule }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0...lastPage, id: \.self) { i in
                Capsule()
                    .fill(i == page ? pal.primary : pal.faint.opacity(0.5))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) { page = i }
                    }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
    }

    private func finish(saveSchedule: Bool) {
        if saveSchedule { prefs.s.schedule = draft }
        prefs.s.onboarded = true
        store.applySchedule()
        Haptics.success()
    }

    // MARK: Páginas

    private func pageText(_ title: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(pal.ink)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(pal.sub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 30)
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            FocusOrb(style: prefs.s.orbStyle, mood: .running, palette: pal)
                .frame(height: 300)
            pageText("Lapsus", "Cronometra tu jornada y descubre, sin culpa, en qué se va tu tiempo.")
            Spacer(minLength: 0)
        }
    }

    private var gesture: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            FocusOrb(style: prefs.s.orbStyle, mood: .paused, palette: pal)
                .frame(height: 200)
            pageText("Un solo gesto", "Todo pasa tocando la ilustración.")
            VStack(alignment: .leading, spacing: 14) {
                step("play.fill", "Tócala para empezar a trabajar.")
                step("pause.fill", "Tócala de nuevo para hacer una pausa.")
                step("questionmark.bubble.fill", "Al volver, te preguntamos qué hiciste.")
                step("flag.checkered", "Al terminar, cierras el día y anotas tus tareas.")
            }
            .padding(.top, 26)
            .padding(.horizontal, 36)
            Spacer(minLength: 0)
        }
    }

    private func step(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(pal.gradient, in: Circle())
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pal.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pauses: some View {
        let sample = ["bebida", "estirar", "redes", "reunion", "conversar", "musica", "correo"]
            .compactMap { PauseCategory.byID[$0] }
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(sample) { cat in
                    HStack(spacing: 7) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(cat.short)
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(cat.group.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 34)
            pageText("Tus pausas cuentan",
                     "Con lo que marcas en cada pausa armamos tus estadísticas: cuándo te concentras mejor y qué te distrae. Puedes buscar, fijar tus pausas frecuentes y crear las tuyas.")
            Spacer(minLength: 0)
        }
    }

    private var schedulePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tu horario")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(pal.ink)
                    Text("Opcional. Define cada día por separado: de él sale tu meta diaria. Lo puedes cambiar cuando quieras en Ajustes.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(pal.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ScheduleEditor(schedule: $draft, use24h: prefs.s.use24h)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }
}
