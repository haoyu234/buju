with open("assets/tpl.html") as f:
  text = f.read()
  with open("tools/viewer/app.js") as js:
    text = text.replace("SCRIPT", js.read())
  with open("tools/viewer/assets/styles.css") as css:
    text = text.replace("STYLE", css.read())
  with open("assets/viewer.html", "w") as out:
    out.write(text)
