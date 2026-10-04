package open

import (
	"strings"
	"list"
)

// #Listing is the author card at custom."opmodel.dev@v0".listing, shaped
// from the v2 marketplace design table (section 2.1). Concrete data only:
// CUE reads the module file in data mode.
#Listing: {
	schemaVersion!: 1
	title!:         strings.MinRunes(1) & strings.MaxRunes(64) & !~"\n"
	summary!:       strings.MinRunes(1) & strings.MaxRunes(160) & !~"\n"
	category!:      #Label
	keywords?: [...#Keyword] & list.MaxItems(10)
	icon?:     #AssetPath & =~"\\.(svg|png)$"
	screenshots?: [...{
		path!:    #AssetPath & =~"\\.(png|jpe?g|webp)$"
		caption?: strings.MaxRunes(120)
	}] & list.MaxItems(4)
	readme?: =~"\\.md$" & !~"^/" & !~"\\.\\."
	links?: [...{
		kind!: "homepage" | "source" | "docs" | "support" | "issues" | "chat"
		url!:  =~"^https://" & strings.MaxRunes(512)
	}] & list.MaxItems(8)
	maintainers?: [...{
		name!:  strings.MinRunes(1) & strings.MaxRunes(64)
		email?: =~"^[^@ ]+@[^@ ]+$"
		url?:   =~"^https://"
	}] & list.MaxItems(10)
	vendor?:  strings.MaxRunes(64)
	license?: strings.MaxRunes(64)
	deprecated?: {
		message!:     strings.MinRunes(1) & strings.MaxRunes(200)
		replacement?: #ModulePathType
	}
	// Reserved for additive i18n; refused when present.
	locales?: _|_
}

#Label:     =~"^[a-z0-9][a-z0-9-]*$" & strings.MaxRunes(32)
#Keyword:   =~"^[a-z0-9][a-z0-9-]*$" & strings.MaxRunes(32)
#AssetPath: =~"^assets/[A-Za-z0-9._/-]+$" & !~"\\.\\."
