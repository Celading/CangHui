/*
 * 字体加载视图层：标题 + 字体样本册（每种字体以自身渲染同一样张 + 文件路径）+ 字体选择器 + 大样张。
 *
 * 样本册固定并列展示系统默认、衬线、等宽三种字体；选择器切换大样张所用字体，Chip 叠加粗体。
 * 字体状态（文件路径 / 回退提示）读全局 `Fonts` 注册表现算。
 */
package cui_fonts

import cui.{Chip, CrossAxisAlignment, Divider, FontSizes, Fonts, HStack, Label, LengthUnits, Panel, ScrollView,
    SegmentedControl, VStack}

func fontsView(model: FontsModel): Unit {
    ScrollView {
        VStack {
            header()
            bookPanel(model)
            specimenPanel(model)
        }.spacing(16.vp).padding(22.vp)
    }
}

private func header(): Unit {
    VStack {
        Label("字体加载").fontSize(FontSizes.TITLE).bold()
        Label("Fonts.register 从本地字体文件加载，Label.fontFamily 套用；找不到文件自动回退系统字体").muted()
            .fontSize(FontSizes.CAPTION)
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 字体样本册：每种字体以其自身渲染同一样张行，下方小字标注文件路径或回退状态。
private func bookPanel(model: FontsModel): Unit {
    Panel {
        VStack {
            Label("字体样本").muted().fontSize(FontSizes.CAPTION)
            for (face in model.faces) {
                bookRow(face)
            }
        }.spacing(14.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

private func bookRow(face: TypeFace): Unit {
    VStack {
        Label(face.label).muted().fontSize(FontSizes.CAPTION)
        fontSpecimen(SPECIMEN, FontSizes.BODY, face.family, false, wrap: false)
        Label(faceStatus(face)).muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 大样张：选择器切换字体、Chip 叠加粗体，样张以所选字体渲染整段。
private func specimenPanel(model: FontsModel): Unit {
    Panel {
        VStack {
            HStack {
                SegmentedControl(model.labels(), model.selected, key: "font-picker").flex()
                Chip("粗体", model.bold, key: "specimen-bold")
            }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
            Divider()
            fontSpecimen(SPECIMEN, FontSizes.TITLE, model.currentFace(), model.bold.value, wrap: true)
            Label("提示：等宽字体下数字与字母等宽对齐，衬线字体带衬脚。Georgia/Consolas 等拉丁字体不含 CJK，中文仍用系统字体。")
                .muted().fontSize(FontSizes.CAPTION).wrap()
        }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

// 发射一个配置好的样张 Label：可选字体、可选粗体、单行截断或换行。
private func fontSpecimen(text: String, size: Float32, family: ?String, bold: Bool, wrap!: Bool): Unit {
    let label = Label(text).fontSize(size)
    if (wrap) {
        let _ = label.wrap()
    } else {
        let _ = label.maxLines(1)
    }
    if (let Some(name) <- family) {
        let _ = label.fontFamily(name)
    }
    if (bold) {
        let _ = label.bold()
    }
}

// 字体的加载状态：系统字体、已加载的文件路径，或未找到时的回退提示。
private func faceStatus(face: TypeFace): String {
    match (face.family) {
        case None => "系统 UI 字体"
        case Some(name) => match (Fonts.pathFor(name)) {
            case Some(path) => path
            case None => "未找到字体文件，已回退系统字体"
        }
    }
}
