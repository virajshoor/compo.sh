from pathlib import Path
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT

root = Path(__file__).resolve().parent.parent
styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="TitleCustom", fontName="Helvetica-Bold", fontSize=38, leading=42, textColor=HexColor("#173b2c"), spaceAfter=20))
styles.add(ParagraphStyle(name="Section", fontName="Helvetica-Bold", fontSize=19, leading=24, textColor=HexColor("#173b2c"), spaceAfter=16))
styles.add(ParagraphStyle(name="BodyCustom", fontName="Helvetica", fontSize=11, leading=17, textColor=HexColor("#25392f"), spaceAfter=12))
styles.add(ParagraphStyle(name="CodeCustom", fontName="Courier", fontSize=9, leading=14, spaceAfter=12))
story=[]
def text(value, style="BodyCustom"):
    story.append(Paragraph(value,styles[style]))
def page(title):
    if story: story.append(PageBreak())
    text(title,"Section")
def footer(canvas, doc):
    canvas.setFillColor(HexColor("#f5f2e9")); canvas.rect(0,0,595.28,841.89,fill=1,stroke=0)
    canvas.setFillColor(HexColor("#597064")); canvas.setFont("Helvetica",9)
    canvas.drawString(48,31,"compo.sh / User guide / 0.2.0 beta")
    canvas.drawRightString(547,31,str(doc.page))

text("compo.sh", "TitleCustom")
text("A little order.<br/>A lot of room.","TitleCustom")
text("USER GUIDE / VERSION 0.2.0 BETA")
text("A native menu bar window manager for macOS 13 and later. Universal app for Apple Silicon and Intel.")
text("Start here", "Section")
text("1. Put compo.sh.app in Applications before granting permissions.<br/>2. Open it manually. Choose Allow Accessibility Access and enable compo.sh in System Settings.<br/>3. Close other window managers. Enable Automatic Tiling when ready.<br/>4. Click the tiled menu bar icon whenever you want the controls.")
text("This guide is bundled inside the app. Open Guide PDF works offline and opens your default PDF viewer.")
text("Contents: setup and permissions (2), layouts and dragging (3), controls and rules (4), login and updates (5), troubleshooting and limits (6).")

page("01 / Permissions and first launch")
text("Why Accessibility is needed", "Section")
text("compo.sh reads window positions, moves and resizes windows, and focuses your chosen window through macOS Accessibility APIs. It does not record screen images. Visible-window metadata helps exclude windows on other Spaces.")
text("Choose Allow Accessibility Access in the controls, then approve the app under System Settings > Privacy &amp; Security > Accessibility. macOS owns approval; the app cannot grant access to itself. Return to compo.sh and enable Automatic Tiling.")
text("Start paused", "Section")
text("A fresh install starts paused. Granting Accessibility does not start tiling. Later launches remember your Automatic Tiling choice. Pausing leaves windows at their current positions and restores native tiling preferences saved by compo.sh.")
text("Manual launch vs login launch", "Section")
text("Opening the app yourself opens controls. Launch at Login starts silently in the menu bar, with no controls window or permission alert. If access is missing, open controls using the menu bar icon to see the permission explanation. Silent launch does not bypass permissions.")
text("Only one manager", "Section")
text("Quit AeroSpace, yabai, or other window managers while testing compo.sh. Multiple managers can repeatedly resize the same windows.")

page("02 / Layouts, snapping and swaps")
text("App-Aware Layout", "Section")
text("Browsers receive more width than terminals when paired. Terminals and documents prefer tall columns. Two browser windows use wide rows. Safari plus Word uses tall side-by-side panes. App rules can override classification. If multiple companion columns would become too narrow, they stack into a balanced two-column grid. Ultrawide displays retain full-height companion columns.")
text("Manual layouts", "Section")
text("Turn off App-Aware Layout or click a layout button: Stack gives one main pane with companions; Columns gives equal tall panes; Rows gives equal wide panes. Window Gap changes spacing. Main Width applies to manual Stack.")
text("Snap Edges", "Section")
text("While Automatic Tiling and Snap Edges are on, drag a managed window to an edge or corner. A foreground outline previews the destination; release to snap. Left and right create halves; corners create quarters; the top edge fills the usable display. Bottom creates a bottom half. Edge Reach controls activation distance.")
text("On macOS 15 and later, compo.sh temporarily disables native edge, top-edge, and Option-drag tiling preferences. Previous values return when Snap Edges is off, tiling is paused, or the app quits normally. These macOS preferences are undocumented and can change after OS updates.")
text("Drag to Swap and animation", "Section")
text("Drag a window into another managed window to preview a position swap. Release to swap. Animate Window Moves controls short transitions and respects Reduce Motion. Manual placements remain until window membership changes or you choose Retile Now. Apps may enforce minimum sizes.")

page("03 / Keyboard controls and app rules")
text("Keyboard controls", "Section")
rows=[["Control + Option + arrows","Focus in that direction"],["Control + Option + Shift + arrows","Swap in that direction"],["Control + Option + L","Cycle manual layouts"],["Control + Option + Space","Float or tile focused window"],["Control + Option + Return","Zoom focused window"],["Control + Option + P","Pause or resume"],["Control + Option + R","Clear placement and retile"]]
table=Table(rows,colWidths=[272,227],hAlign="LEFT")
table.setStyle(TableStyle([("FONTNAME",(0,0),(-1,-1),"Helvetica"),("FONTSIZE",(0,0),(-1,-1),9),("BOTTOMPADDING",(0,0),(-1,-1),11),("TEXTCOLOR",(0,0),(-1,-1),HexColor("#25392f")),("LINEBELOW",(0,0),(-1,-1),.4,HexColor("#cdd6cb"))]))
story.append(table);story.append(Spacer(1,20))
text("Edit App Rules", "Section")
text("Edit App Rules creates and opens a JSON file in your default editor. Use exact app bundle identifiers. Reload Rules applies edits; invalid JSON keeps the last working rules and shows an error. Maximum file size is 256 KB.")
text('File: ~/Library/Application Support/compo/config.json',"CodeCustom")
text('{"apps": {<br/>&nbsp;&nbsp;"com.apple.Safari": {"role": "browser"},<br/>&nbsp;&nbsp;"com.apple.Terminal": {"role": "terminal"},<br/>&nbsp;&nbsp;"com.apple.calculator": {"floating": true}<br/>}}',"CodeCustom")
text("Allowed roles: browser, terminal, document, other. Floating apps stay outside tiling. Manual floating and zoom last only for the current session. Shortcuts are fixed and may conflict with VoiceOver or other apps.")

page("04 / Silent startup and safe updates")
text("Launch at Login", "Section")
text("Enable Launch at Login in controls to register with macOS. If approval is needed, use Approve in Login Items and finish in System Settings. The switch reflects the actual macOS registration state. Nothing enables it automatically on a fresh install.")
text("On your next login the app starts silently in the menu bar. It uses your saved tiling and snapping choices. Click the menu bar icon to open controls. Opening the app manually still opens controls.")
text("What survives updates", "Section")
text("Automatic Tiling, App-Aware Layout, chosen layout, gap, main width, Snap Edges, Drag to Swap, animation, and Edge Reach persist in the app's preferences. App rules live separately in Application Support. Login registration is managed by macOS and remains attached to the stable app identity and location.")
text("Update procedure", "Section")
text("1. Quit compo.sh using its controls so native tiling preferences are restored.<br/>2. Replace /Applications/compo.sh.app with the complete new app bundle.<br/>3. Keep the same Applications location. Do not delete preferences or Application Support.<br/>4. Open manually once to confirm the update, or let the next login start it silently.")
text("The bundle identifier remains dev.compo.app even though the display name is compo.sh. That preserves existing preferences. Updates must retain this identity and Developer ID signing team. An update does not unregister the login item or reset preferences. Your explicit changes in macOS Login Items remain authoritative; compo.sh will not silently re-enable an item you disable there.")
text("macOS can still require renewed approval after a signing change, relocation, or system policy change. No app can guarantee those approvals survive every OS update.")

page("05 / Troubleshooting and boundaries")
text("Windows refuse to fit", "Section")
text("Some apps impose minimum sizes or reject Accessibility writes. Float those windows or reduce the number of tiles. Dialogs, non-resizable windows, hidden apps, minimized windows, native fullscreen windows, and compo.sh itself are excluded.")
text("Native snap still appears", "Section")
text("Confirm Automatic Tiling and Snap Edges are on. If preference writes fail, controls show a message; check Desktop &amp; Dock tiling settings. Native integration uses undocumented preferences, not private WindowServer hooks. macOS changes may require a future app update.")
text("After a crash", "Section")
text("A crash can leave native tiling disabled. Reopen compo.sh, then pause tiling or turn off Snap Edges to restore the saved native settings. If you cannot reopen it, change native tiling manually in System Settings > Desktop &amp; Dock.")
text("Permissions or startup problems", "Section")
text("Keep one copy in Applications. If macOS no longer recognizes Accessibility approval, remove the old entry and re-add the installed app. Check System Settings > General > Login Items for startup approval. Updating with the same bundle ID and signing team reduces approval churn.")
text("Stop or remove", "Section")
text("Pause with Control + Option + P, or quit from controls. Before removing the app, disable Launch at Login, then quit normally. Revoke Accessibility if desired. Quitting does not restore earlier window frames.")
text("Scope", "Section")
text("compo.sh arranges existing windows. It is not a replacement compositor and does not add custom Spaces, Mission Control behavior, shaders, or Hyprland effects. This beta has automated geometry and launch-event checks; app-specific dragging and real login behavior still need testing on your Mac.")
text('Apple reference: <link href="https://developer.apple.com/documentation/coreservices/keyaelaunchedasloginitem" color="#173b2c">Login launch event</link>.')

out=root/'Resources/compo.sh-guide.pdf'
SimpleDocTemplate(str(out),pagesize=(595.28,841.89),leftMargin=48,rightMargin=48,topMargin=52,bottomMargin=54,title="compo.sh User Guide",author="compo.sh",subject="Setup, layouts, snapping, startup and updates").build(story,onFirstPage=footer,onLaterPages=footer)
print(out)
