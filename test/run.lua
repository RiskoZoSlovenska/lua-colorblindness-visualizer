local colorblindness = require("../colorblindness")
local utils = require("vips-utils")



local case     = utils.normalizedFromFile("case.png")
local expected = utils.normalizedFromFile("expected.png")

assert(    utils.equal(case, case))
assert(not utils.equal(case, expected))

local base = utils.normalize(case)
local processed = colorblindness.applyFilterToImage(base, colorblindness.CbFilterType.Tritanopia)

local actual = utils.writeAndRead(processed)

assert(utils.equal(actual, expected))

print("Tests passed!")