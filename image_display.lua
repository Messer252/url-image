-- image_display.lua
-- CC:Tweaked program: asks for a URL to an .nfp (ComputerCraft paint format)
-- image and displays it on a connected monitor, auto-fitting the scale
-- to whatever size monitor you've got hooked up.
--
-- NOTE: This does NOT decode PNG/JPEG/etc. CC:Tweaked has no image codec
-- built in. It expects the URL to point to a plain-text .nfp file
-- (the format used by the in-game `paint` program: one hex digit 0-f
-- per pixel, one row per line).
--
-- To turn a normal photo into .nfp, convert it first with a tool like:
--   https://github.com/DownrightNifty/computercraft-stuff
-- then host the .nfp file somewhere you can link to as raw text
-- (Pastebin "raw" link, GitHub raw, etc.) and paste that URL below.
--
-- Full color (16-color) output requires an ADVANCED monitor (made with
-- gold, not iron). A normal monitor will still work but colors may not
-- render as expected.

local function findMonitor()
    local mon = peripheral.find("monitor")
    if not mon then
        error("No monitor connected. Please attach a monitor to this computer with a modem/wired connection.", 0)
    end
    return mon
end

local function fetchImageData(url)
    if not http then
        error("The HTTP API is disabled on this computer. Ask a server admin to enable it in the CC config.", 0)
    end

    local response, errMsg = http.get(url)
    if not response then
        error("Failed to fetch image: " .. tostring(errMsg or "unknown error"), 0)
    end

    local data = response.readAll()
    response.close()
    return data
end

-- Finds the largest text scale where the monitor's character grid is
-- still big enough to fit the whole image (each pixel = 1 character cell).
local function bestFitScale(mon, imgW, imgH)
    local scales = { 5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1, 0.5 }
    for _, scale in ipairs(scales) do
        mon.setTextScale(scale)
        local w, h = mon.getSize()
        if w >= imgW and h >= imgH then
            return scale, w, h
        end
    end
    -- Nothing fit even at max resolution; use the smallest scale (most cells)
    mon.setTextScale(0.5)
    local w, h = mon.getSize()
    return 0.5, w, h
end

local function main()
    local mon = findMonitor()

    term.clear()
    term.setCursorPos(1, 1)
    print("=== CC:Tweaked Image Display ===")
    print("Enter the URL of an .nfp image (raw text link).")
    write("URL: ")
    local url = read()

    if url == nil or url == "" then
        print("No URL entered, exiting.")
        return
    end

    print("Downloading...")
    local ok, result = pcall(fetchImageData, url)
    if not ok then
        printError(result)
        return
    end

    local ok2, image = pcall(paintutils.parseImage, result)
    if not ok2 or not image or #image == 0 then
        printError("Could not parse image data. Make sure the URL points to a valid .nfp file (plain text, not PNG/JPEG).")
        return
    end

    local imgH = #image
    local imgW = 0
    for _, row in ipairs(image) do
        if #row > imgW then imgW = #row end
    end

    if imgW == 0 then
        printError("Downloaded image appears to be empty.")
        return
    end

    print("Image size: " .. imgW .. "x" .. imgH)
    print("Fitting to monitor...")

    local scale, monW, monH = bestFitScale(mon, imgW, imgH)
    print("Using text scale " .. scale .. " (" .. monW .. "x" .. monH .. " cells)")

    if monW < imgW or monH < imgH then
        print("Warning: image is larger than the monitor even at max")
        print("resolution (0.5 scale). It will be cropped to fit.")
    end

    -- Center the image on the monitor
    local xOffset = math.max(0, math.floor((monW - imgW) / 2))
    local yOffset = math.max(0, math.floor((monH - imgH) / 2))

    mon.setBackgroundColor(colors.black)
    mon.clear()

    local old = term.redirect(mon)
    paintutils.drawImage(image, 1 + xOffset, 1 + yOffset)
    term.redirect(old)

    print("Done! Image displayed on monitor.")
end

main()
