import buju
import cdp

import std/asyncdispatch
import std/json
import std/os
import std/strutils
import std/times

const
  PATH_VIEWER_HTML = currentSourcePath().parentDir.parentDir.parentDir /
               "assets" / "viewer.html"

  URL_VIEWER_HTML = "file:///" & PATH_VIEWER_HTML.replace('\\', '/')

  STARTUP_TIMEOUT = int32(15000)
  LAYOUT_TIMEOUT = int32(10000)
  EVAL_TIMEOUT = int32(20000)

  MAX_ATTEMPTS = int32(5)

  OPEN_TIMEOUT = int32(30000)

  CHROME_ARGS = @[
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--hide-scrollbars",
    "--allow-file-access-from-files",
    "--force-device-scale-factor=1",
    "--window-size=1600,1200"]

type
  WebDriverError* = object of CatchableError

  LayoutEntry* = object
    ## Geometry for one node: what buju computed versus what the browser
    ## actually laid out, both in layout units.
    id*: NodeID
    jsBuju*: array[4, float32]
    jsHtml*: array[4, float32]

  Browser* = ref BrowserObj
  BrowserObj = object
    browser: cdp.Browser
    page: cdp.Tab
    attempts: int32

proc `=destroy`*(b: BrowserObj) =
  if b.browser.isNil:
    return

  try:
    discard waitFor b.browser.close().withTimeout(OPEN_TIMEOUT)
  except Exception:
    discard

proc close*(b: Browser) {.async.} =
  if not b.browser.isNil:
    try:
      discard waitFor b.browser.close().withTimeout(OPEN_TIMEOUT)
    except Exception:
      discard

    b.page = nil
    b.browser = nil

proc evalString(page: cdp.Tab, expr: string,
                timeout: int32 = EVAL_TIMEOUT): Future[JsonNode] {.async.} =
  ## Run `expr` in the page and unwrap the JSON result to the plain JS value
  ## (nil when the expression yields no value). Raises WebDriverError
  ## if the page does not respond within `timeout` milliseconds.
  let
    pending = page.evaluate(expr, %*{"returnByValue": true})
  if not await pending.withTimeout(timeout):
    raise newException(WebDriverError,
      "cdp: evaluate timed out after " & $timeout & " ms")

  let
    r = await pending
    ex = r{"result", "exceptionDetails"}

  if not ex.isNil:
    let detail = ex{"exception", "description"}.getStr(
                   ex{"text"}.getStr("unknown script error"))
    raise newException(WebDriverError, "cdp: script evaluation failed: " & detail)

  result = r{"result", "result", "value"}

proc waitUntil(page: cdp.Tab, expr: string, timeout: int32,
               predicate: proc (v: JsonNode): bool): Future[bool] {.async.} =
  let deadline = epochTime() + float32(timeout) / 1000
  while epochTime() < deadline:
    let v = await page.evalString(expr)
    if not v.isNil and predicate(v):
      result = true
      return

    await sleepAsync(1000)

proc openPage(b: cdp.Browser): Future[cdp.Tab] {.async.} =
  let
    page = await b.newTab()

  await page.enablePageDomain()
  discard await page.navigate(URL_VIEWER_HTML)
  discard await b.waitForSessionEvent(page.sessionId,
                                              $Page.domContentEventFired)
  await page.disablePageDomain()

  if not await page.waitUntil("typeof importJsonString", STARTUP_TIMEOUT,
                       proc (v: JsonNode): bool = v.getStr("") == "function"):
    raise newException(WebDriverError,
      "cdp: viewer did not expose importJsonString() within " &
      $STARTUP_TIMEOUT & " ms (" & PATH_VIEWER_HTML & ")")

  page

proc initializeBrowser(b: Browser) {.async.} =
  await b.close()

  let
    browser = await launchBrowser(
      headlessMode = HeadlessMode.Off,
      chromeArguments = CHROME_ARGS)

  try:
    b.browser = browser
    b.page = await browser.openPage()

  finally:
    if b.page.isNil:
      await b.close()

proc openBrowserAndPage*(): Future[Browser] {.async.} =
  result = Browser()
  await result.initializeBrowser()

proc layoutJsonString*(b: Browser, bujuJsonString: string): Future[seq[
    LayoutEntry]] {.async.} =
  while true:
    result.setLen(0)

    try:
      discard await b.page.evalString("importJsonString(" & escapeJson(
          bujuJsonString) & ")")

      if not await b.page.waitUntil(
          "document.querySelectorAll('.viewer-html5 .node').length",
          LAYOUT_TIMEOUT,
          proc (v: JsonNode): bool = v.getFloat(0) > 0):
        raise newException(WebDriverError,
          "cdp: layout produced no rendered nodes within " &
          $LAYOUT_TIMEOUT & " ms")

      let v = await b.page.evalString("dumpResultString()")
      if v.isNil or v.kind != JString or v.getStr.len == 0:
        raise newException(WebDriverError, "cdp: dumpResultString() returned no layout data")

      for j in parseJson(v.getStr):
        let
          r = j["computed"]
          bujuRect = r[0]
          htmlRect = r[1]

        var
          item = default(LayoutEntry)
        item.id = cast[NodeID](j["id"].getInt)

        for idx in 0 ..< 4:
          item.jsBuju[idx] = bujuRect[idx].getFloat()
          item.jsHtml[idx] = htmlRect[idx].getFloat()
        result.add(item)

      b.attempts = 0
      return

    except WebDriverError:
      inc b.attempts, 1
      if b.attempts >= MAX_ATTEMPTS:
        raise

      await initializeBrowser(b)
