# `license_page`

A crate for generating dependency license pages.

`license_page` uses [`cargo-license`](https://crates.io/crates/cargo-license)
to fetch the licenses and authorship of a crate's dependencies,
then fetches the text of licenses (and exceptions).
It will first check if a license is present in [the licenses from `choosealicense.com`](https://github.com/github/choosealicense.com/tree/gh-pages/_licenses)
(which provides hand-wrapped copies license texts),
otherwise it will pull the text from [`spdx`](https://crates.io/crates/spdx)
(which themselves are drawn from [SPDX's plain text license dumps](https://github.com/spdx/license-list-data/tree/main/text)).
Only licenses and exceptions from the [SPDX License List](https://spdx.org/licenses) are supported.

## Stability

I'm intentionally writing low-quality and unstable code
because I'm trying to get something functional for myself
before I adapt it to being useful to others.

### MSRV

`license_page` supports only the latest stable Rust.
Older version _may_ work, but are not tested.
MSRV naturally being bumped as new stable versions release
is not considered a breaking change.

## License

`license_page` uses license texts from [`github/choosealicense.com`](https://github.com/github/choosealicense.com).
These license texts are presumably still copyright of their original owners,
but the modifications by `choosealicense.com` contributors might (I'm not a lawyer) be licensed [Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/).

`license_page` is licensed under the Mozilla Public License,
version 2.0 or (as the license stipulates) any later version.
A copy of the license should be distributed with `license_page`,
located at [`LICENSE`](./LICENSE),
or you can obtain one at
<https://mozilla.org/MPL/2.0/>.
