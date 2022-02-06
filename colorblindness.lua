--[[lit-meta
	name = "RiskoZoSlovenska/colorblindness"
	version = "0.1.0"
	homepage = "https://github.com/RiskoZoSlovenska/lua-colorblindness-visualizer"
	description = "A small library for apply colorblindness filters onto images."
	tags = {"colorblindness", "image-processing", "images"}
	dependencies = {
		"RiskoZoSlovenska/vips-utils@0.1.0"
	}
	license = "MIT"
	author = "RiskoZoSlovenska"
]]

local Image = require("vips").Image
local newMatrix = Image.new_from_array

local utils = require("vips-utils")



local XyzToLmsMatrixType = {
	HuntPointerEstevez = 0,
}
local CbFilterType = {
	Protanopia = 0,
	Deuteranopia = 1,
	Tritanopia = 2,
	-- TODO
	-- Achromatopsia = 3,
	-- BlueConeMonochromacy = 4,
}


-- TODO: Combine these into one matrix
-- Conversion between RGB and XYZ
-- We could use vips's :colourspace("xyz") (which actually appears do to gamma
-- correction and whatnot too), but doing it manually is simpler and more
-- accurate.)
local RGB_TO_XYZ = newMatrix{
	{0.4124564, 0.3575761, 0.1804375},
	{0.2126729, 0.7151522, 0.0721750},
	{0.0193339, 0.1191920, 0.9503041},
}
local XYZ_TO_RGB = RGB_TO_XYZ:matrixinvert()

-- Conversion between XYZ and LMS
local XYZ_TO_LMS = {
	[XyzToLmsMatrixType.HuntPointerEstevez] = newMatrix{
		{ 0.4002, 0.7076, -0.0808},
		{-0.2263, 1.1653,  0.0457},
		{ 0,      0,       0.9182},
	},
}
local LMS_TO_XYZ = {}
for matrixType, matrixImage in pairs(XYZ_TO_LMS) do
	LMS_TO_XYZ[matrixType] = matrixImage:matrixinvert()
end

-- Actual effect filters to apply once in LMS
local LMS_FILTERS = {
	[CbFilterType.Protanopia] = newMatrix{
		{0,     1.05118294, -0.05116099},
		{0,     1,           0         },
		{0,     0,           1         },
	},
	[CbFilterType.Deuteranopia] = newMatrix{
		{1,             0,     0         },
		{0.9513092,     1,     0.04866992},
		{0,             0,     1         },
	},
	[CbFilterType.Tritanopia] = newMatrix{
		{ 1,          0,          0},
		{ 0,          1,          0},
		{-0.86744736, 1.86727089, 0},
	},
}



local function applyFilterToImage(srcImg, filterType, matrixType)
	filterType = filterType or CbFilterType.Protanopia
	matrixType = matrixType or XyzToLmsMatrixType.HuntPointerEstevez

	local matrixImagesToApply = {
		RGB_TO_XYZ, -- First convert from RGB to XYZ
		XYZ_TO_LMS[matrixType], -- Then from XYZ to LMS
		LMS_FILTERS[filterType], -- Apply CB filter
		LMS_TO_XYZ[matrixType], -- Convert back from LMS to XYZ
		XYZ_TO_RGB, -- Convert back from XYZ to RGB
	}


	local res = utils.removeSrgbGamma(srcImg / 255)
	for _, matrixImage in ipairs(matrixImagesToApply) do
		res = res:recomb(matrixImage) -- Apply matrix
	end

	return utils.addSrgbGamma(res) * 255
end

local function applyFilterToBuffer(buffer, imageFormat, filterType, matrixType)
	local noAlpha, alpha = utils.normalizedFromBuffer(buffer, nil, {access = "sequential"})

	return applyFilterToImage(noAlpha, filterType, matrixType):bandjoin(alpha):write_to_buffer(imageFormat)
end



return {
	applyFilterToImage = applyFilterToImage,
	applyFilterToBuffer = applyFilterToBuffer,

	CbFilterType = CbFilterType,
	XyzToLmsMatrixType = XyzToLmsMatrixType,
}