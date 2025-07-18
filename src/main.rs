// SPDX-License-Identifier: MPL-2.0
//
// Copyright © 2025 RemasteredArch
//
// This Source Code Form is subject to the terms of the Mozilla Public License, version 2.0. If a
// copy of the Mozilla Public License was not distributed with this file, You can obtain one at
// <https://mozilla.org/MPL/2.0/>.

#![warn(clippy::nursery, clippy::pedantic)]

use std::io::BufWriter;

use license_page::CrateList;

fn main() -> std::io::Result<()> {
    let directory_path = std::env::args().nth(1).unwrap_or_else(|| ".".to_string());
    let crates = CrateList::from_crate_directory(directory_path.as_str());

    // Replicates `cargo-license`:
    //
    // ```rust
    // for (count, license, crates) in crates.by_license() {
    //     println!(
    //         "{license} ({count}): {}",
    //         crates
    //             .iter()
    //             .map(|license_page::Crate { name, .. }| name.as_str())
    //             .collect::<Vec<_>>()
    //             .join(", ")
    //     );
    // }
    // ```

    let mut stdout = BufWriter::new(std::io::stdout().lock());
    crates.to_markdown_license_page(&mut stdout)
}
