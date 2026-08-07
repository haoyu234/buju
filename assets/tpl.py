with open("assets/tpl.html", encoding="utf-8") as f:
  text = f.read()
  with open("tools/viewer/app.js", encoding="utf-8") as js:
    text = text.replace("SCRIPT", js.read())
  with open("tools/viewer/assets/styles.css", encoding="utf-8") as css:
    text = text.replace("STYLE", css.read())
  with open("assets/viewer.html", "w", encoding="utf-8") as out:
    out.write(text)
