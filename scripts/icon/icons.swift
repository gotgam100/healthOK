import SwiftUI
import AppKit

// macOS 아이콘 격자: 1024 캔버스, 824 둥근 사각형. 미니멀: 단색 + 기호 하나.
struct Tile<Content: View>: View {
    let bg: [Color]
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: bg, startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
            content.frame(width: 824, height: 824)
        }
        .frame(width: 1024, height: 1024)
    }
}

struct Heart: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX + w/2, y: r.minY + h))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h*0.3),
                   control1: CGPoint(x: r.minX + w*0.2, y: r.minY + h*0.8),
                   control2: CGPoint(x: r.minX, y: r.minY + h*0.55))
        p.addCurve(to: CGPoint(x: r.minX + w/2, y: r.minY + h*0.16),
                   control1: CGPoint(x: r.minX, y: r.minY - h*0.05),
                   control2: CGPoint(x: r.minX + w*0.42, y: r.minY - h*0.02))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h*0.3),
                   control1: CGPoint(x: r.minX + w*0.58, y: r.minY - h*0.02),
                   control2: CGPoint(x: r.maxX, y: r.minY - h*0.05))
        p.addCurve(to: CGPoint(x: r.minX + w/2, y: r.minY + h),
                   control1: CGPoint(x: r.maxX, y: r.minY + h*0.55),
                   control2: CGPoint(x: r.minX + w*0.8, y: r.minY + h*0.8))
        p.closeSubpath()   // 닫아야 선으로 그릴 때 아래 꼭짓점이 잘리지 않음
        return p
    }
}

struct Check: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height*0.55))
        p.addLine(to: CGPoint(x: r.minX + r.width*0.36, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

struct Plus: Shape {   // 둥근 의료 십자
    func path(in r: CGRect) -> Path {
        let t = r.width * 0.34
        var p = Path()
        p.addRoundedRect(in: CGRect(x: r.midX - t/2, y: r.minY, width: t, height: r.height), cornerSize: CGSize(width: t*0.3, height: t*0.3))
        p.addRoundedRect(in: CGRect(x: r.minX, y: r.midY - t/2, width: r.width, height: t), cornerSize: CGSize(width: t*0.3, height: t*0.3))
        return p
    }
}

let green = [Color(red: 0.30, green: 0.80, blue: 0.56), Color(red: 0.12, green: 0.62, blue: 0.45)]
let coral = [Color(red: 1.0, green: 0.50, blue: 0.48), Color(red: 0.93, green: 0.30, blue: 0.36)]
let blue = [Color(red: 0.30, green: 0.60, blue: 1.0), Color(red: 0.16, green: 0.40, blue: 0.88)]
let white = [Color(white: 1.0), Color(white: 0.93)]
let teal = [Color(red: 0.22, green: 0.72, blue: 0.74), Color(red: 0.10, green: 0.50, blue: 0.58)]
let line = StrokeStyle(lineWidth: 64, lineCap: .round, lineJoin: .round)

// D: 체크 하나 — "됐지"
let iconD = Tile(bg: green) {
    Check().stroke(.white, style: line).frame(width: 400, height: 300)
}
// E: 하트 하나
let iconE = Tile(bg: coral) {
    Heart().fill(.white).frame(width: 470, height: 420).offset(y: 20)
}
// F: 의료 십자 안에 체크
let iconF = Tile(bg: white) {
    ZStack {
        Plus().fill(Color(red: 0.12, green: 0.66, blue: 0.48)).frame(width: 500, height: 500)
        Check().stroke(.white, style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round))
            .frame(width: 150, height: 110)
    }
}
// G: 심박선 한 줄
let iconG = Tile(bg: blue) {
    Path { p in
        p.move(to: CGPoint(x: 150, y: 430))
        p.addLine(to: CGPoint(x: 310, y: 430))
        p.addLine(to: CGPoint(x: 370, y: 290))
        p.addLine(to: CGPoint(x: 450, y: 560))
        p.addLine(to: CGPoint(x: 510, y: 430))
        p.addLine(to: CGPoint(x: 674, y: 430))
    }.stroke(.white, style: StrokeStyle(lineWidth: 52, lineCap: .round, lineJoin: .round))
}
// H: 하트 외곽선 + 안쪽 체크
let iconH = Tile(bg: white) {
    ZStack {
        Heart().stroke(Color(red: 0.93, green: 0.32, blue: 0.38), style: StrokeStyle(lineWidth: 52, lineCap: .round, lineJoin: .round))
            .frame(width: 500, height: 450).offset(y: 20)
        Check().stroke(Color(red: 0.12, green: 0.66, blue: 0.48), style: StrokeStyle(lineWidth: 52, lineCap: .round, lineJoin: .round))
            .frame(width: 190, height: 140).offset(y: 10)
    }
}
// I: 정상 범위 띠 안에 머무는 점 세 개 (해마다 확인)
let iconI = Tile(bg: teal) {
    ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 60).fill(.white.opacity(0.22))
            .frame(width: 600, height: 200).offset(x: 112, y: 312)
        Path { p in
            p.move(to: CGPoint(x: 212, y: 470)); p.addLine(to: CGPoint(x: 412, y: 380)); p.addLine(to: CGPoint(x: 612, y: 420))
        }.stroke(.white, style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
        ForEach(0..<3) { i in
            let ys: [CGFloat] = [470, 380, 420]
            Circle().fill(.white).frame(width: 96, height: 96)
                .offset(x: 212 + CGFloat(i)*200 - 48, y: ys[i] - 48)
        }
    }
    .frame(width: 824, height: 824, alignment: .topLeading)
}

@MainActor func save(_ v: some View, _ name: String) {
    let r = ImageRenderer(content: v); r.scale = 1
    guard let cg = r.cgImage else { print("fail", name); return }
    try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(filePath: name))
}

@MainActor func run() {
    let icons: [(String, AnyView)] = [("D  체크", AnyView(iconD)), ("E  하트", AnyView(iconE)), ("F  십자 + 체크", AnyView(iconF)),
                                     ("G  심박선", AnyView(iconG)), ("H  하트 + 체크", AnyView(iconH)), ("I  정상 범위 추이", AnyView(iconI))]
    for (n, v) in icons { save(v, "\(n.prefix(1)).png") }
    func row(_ part: ArraySlice<(String, AnyView)>, _ bg: Color, _ dark: Bool) -> some View {
        HStack(spacing: 36) {
            ForEach(Array(part.enumerated()), id: \.offset) { _, e in
                VStack(spacing: 12) {
                    e.1.scaleEffect(0.22).frame(width: 225, height: 225)
                    HStack(spacing: 10) {
                        e.1.scaleEffect(64/1024).frame(width: 64, height: 64)
                        e.1.scaleEffect(32/1024).frame(width: 32, height: 32)
                        e.1.scaleEffect(16/1024).frame(width: 16, height: 16)
                    }
                    Text(e.0).font(.system(size: 19, weight: .semibold)).foregroundStyle(dark ? .white : .black)
                }
            }
        }.padding(30).frame(maxWidth: .infinity).background(bg)
    }
    let sheet = VStack(spacing: 0) {
        row(icons[0..<3], Color(white: 0.95), false)
        row(icons[3..<6], Color(white: 0.95), false)
        row(icons[0..<3], Color(white: 0.15), true)
        row(icons[3..<6], Color(white: 0.15), true)
    }.frame(width: 900)
    save(sheet, "icon_options2.png")
}
MainActor.assumeIsolated { run() }
