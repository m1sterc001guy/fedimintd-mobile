#![allow(unexpected_cfgs)]

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

use fedimint_core::{anyhow, fedimint_build_code_version_env};
use fedimintd::Fedimintd;
use flutter_rust_bridge::frb;

#[frb]
pub async fn start_fedimintd(path: String) -> anyhow::Result<()> {
    println!("Starting fedimintd...");
    std::env::set_var("FM_FORCE_IROH", "1");
    std::env::set_var("FM_DATA_DIR", path);
    std::env::set_var("FM_BITCOIN_NETWORK", "signet");
    std::env::set_var("FM_BITCOIN_RPC_KIND", "esplora");
    std::env::set_var("FM_BITCOIN_RPC_URL", "https://mutinynet.com/api");
    std::env::set_var("FM_BIND_API_IROH", "0.0.0.0:8174");
    std::env::set_var("FM_BIND_UI", "0.0.0.0:8175");
    Fedimintd::new(fedimint_build_code_version_env!(), None)?
        .with_default_modules()?
        .run()
        .await
}
