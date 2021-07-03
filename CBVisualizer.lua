--[[--
	@author RiskoZoSlovenska

	A slightly more mathematical algorithm where RGB pixels are converted to the LMS colorspace and then from there
	various matrix filters can be applied.
	This is based off of https://ixora.io/projects/colorblindness/color-blindness-simulation-research/, which also
	gives a very in-depth explanation. The algorithm and most matrixes were pulled from that site.

	DISCLAIMER: I barely understand the concept of matrixes, don't expect me to get all this fancy color math aaaaaaa
]]

local vips = require("vips")

local Image = vips.Image
local matrixImg = Image.new_from_array


local XYZToLMSMatrixType = {
	HuntPointerEstevez = 1,
}
local CBFilterType = {
	Protanopia = 1,
	Protanomaly = 2,

	Deuteranopia = 3,
	Deuteranomaly = 4,

	Tritanopia = 5,
	Tritanomaly = 6,

	Achromatopsia = 7,
	Achromatomaly = 8,
}




--[[--
	Pretty much copy-pasted from https://stackoverflow.com/a/18504573.

	This math is too high-level for me currently ;-;
]]
local function matrixInvert(matrix)
	local a, b, c = unpack(matrix)
	local a1, a2, a3 = unpack(a)
	local b1, b2, b3 = unpack(b)
	local c1, c2, c3 = unpack(c)

	local determinant =
		a1 * (b2 * c3 - c2 * b3) -
		a2 * (b1 * c3 - b3 * c1) +
		a3 * (b1 * c2 - b2 * c1)

	local invDet = 1 / determinant

	return {
		{
			(b2 * c3 - c2 * b3) * invDet,
			(a3 * c2 - a2 * c3) * invDet,
			(a2 * b3 - a3 * b2) * invDet,
		},
		{
			(b3 * c1 - b1 * c3) * invDet,
			(a1 * c3 - a3 * c1) * invDet,
			(b1 * a3 - a1 * b3) * invDet,
		},
		{
			(b1 * c2 - c1 * b2) * invDet,
			(c1 * a2 - a1 * c2) * invDet,
			(a1 * b2 - b1 * a2) * invDet,
		},
	}
end


-- Conversion between RGB and XYZ
local RGB_TO_XYZ_MATRIX_IMAGE, XYZ_TO_RGB_MATRIX_IMAGE
do
	local rawRGBToXYZ = {
		{0.4124564, 0.3575761, 0.1804375},
		{0.2126729, 0.7151522, 0.0721750},
		{0.0193339, 0.1191920, 0.9503041},
	}

	RGB_TO_XYZ_MATRIX_IMAGE = matrixImg(rawRGBToXYZ)
	XYZ_TO_RGB_MATRIX_IMAGE = matrixImg(matrixInvert(rawRGBToXYZ))
end

-- Conversion between XYZ and LMS
local XYZ_TO_LMS_MATRIX_IMAGES, LMS_TO_XYZ_MATRIX_IMAGES
do
	local rawXYZToLMS = {
		[XYZToLMSMatrixType.HuntPointerEstevez] = {
			{0.4002,	0.7076,		-0.0808},
			{-0.2263,	1.1653,		0.0457},
			{0,			0,			0.9182},
		},
	}


	XYZ_TO_LMS_MATRIX_IMAGES, LMS_TO_XYZ_MATRIX_IMAGES = {}, {}

	for key, matrix in pairs(rawXYZToLMS) do
		XYZ_TO_LMS_MATRIX_IMAGES[key] = matrixImg(matrix)
		LMS_TO_XYZ_MATRIX_IMAGES[key] = matrixImg(matrixInvert(matrix))
	end
end

-- Actual effect filters to apply once in LMS
local LMS_FILTER_MATRIX_IMAGES = {
	[CBFilterType.Tritanopia] = {
		{1,				0,			0},
		{0,				1,			0},
		{-0.86744736,	1.86727089,	0},
	},
}


-- gamma magic i guess
local function removeGamma(image)
	return image:more(0.04045 * 255):ifthenelse(
		((image / 255 + 0.055) / 1.055)^2.4,
		(image / 255) / 12.92
	)
end

local function addGamma(image)
	return image:more(0.0031308):ifthenelse(
		255 * (1.055 * image^0.41666 - 0.055),
		255 * (12.92 * image)
	)
end



--[[--
	@param srcImg VipsImage the raw 3-band sRGB image to apply the filter to
	@param[opt=CBFilterType.Tritanopia] filterType CBFilterType a supported color blindness filter type
	@param[opt=XYZToLMSMatrixType.HuntPointerEstevez] matrixType XYZToLMSMatrixType a supported matrix type for the XYZ -> LMS operation

	@return VipsImage the filtered image
]]
local function processVipsImage(srcImg, filterType, matrixType)
	filterType = filterType or CBFilterType.Tritanopia
	matrixType = matrixType or XYZToLMSMatrixType.HuntPointerEstevez

	local matrixImagesToApply = {
		RGB_TO_XYZ_MATRIX_IMAGE, -- First convert from RGB to XYZ
		XYZ_TO_LMS_MATRIX_IMAGES[matrixType], -- Then from XYZ to LMS
		LMS_FILTER_MATRIX_IMAGES[filterType], -- Apply CB filter
		LMS_TO_XYZ_MATRIX_IMAGES[matrixType], -- Convert back from LMS to XYZ
		XYZ_TO_RGB_MATRIX_IMAGE, -- Convert back from XYZ to RGB
	}

	-- Remember to remove and add the gamma
	local res = removeGamma(srcImg)
	for _, matrixImage in ipairs(matrixImagesToApply) do
		res = res:recomb(matrixImage) -- Apply matrix
	end

	return addGamma(res)
end


--[[--
	Utility function, takes an image buffer, cleans it and returns the resulting VipsImages.

	@param string buffer the buffer from which to create the image
	@param string imageFormat the MIME type subformat, with no leading period

	@return VipsImage the non-alpha image
	@return VipsImage | 255 the alpha band
]]
local function cleanBufferToVipsImage(buffer, imageFormat)
	local image = Image.new_from_buffer(buffer, "." .. imageFormat, {access = "sequential"}):colourspace("srgb")

	local bandsCount = image:bands()
	local noAlpha, alpha
	if bandsCount == 1 or bandsCount == 3 then
		alpha = 255
		noAlpha = image
	else
		local bands = image:bandsplit()
		alpha = table.remove(bands)
		noAlpha = Image.bandjoin(bands)
	end

	return noAlpha, alpha
end


--[[--
	Similar to processVipsImage(), except it takes a buffer and returns a buffer instead of a VipsImage.

	This is mostly a wrapper.

	@see cleanBufferToVipsImage()
	@see processVipsImage()

	@param string buffer
	@param string imageFormat
	@param[opt=CBFilterType.Tritanopia] filterType CBFilterType
	@param[opt=XYZToLMSMatrixType.HuntPointerEstevez] matrixType XYZToLMSMatrixType

	@return string the returned buffer in the same format
]]
local function processBuffer(buffer, imageFormat, filterType, matrixType)
	local noAlpha, alpha = cleanBufferToVipsImage(buffer, imageFormat)

	return processVipsImage(noAlpha, filterType, matrixType):bandjoin(alpha):write_to_buffer("." .. imageFormat)
end


return {
	cleanBufferToVipsImage = cleanBufferToVipsImage,

	processVipsImage = processVipsImage,
	processBuffer = processBuffer,

	CBFilterType = CBFilterType,
	XYZToLMSMatrixType = XYZToLMSMatrixType,

	supportedFilterTypes = {
		CBFilterType.Tritanopia,
	},
}