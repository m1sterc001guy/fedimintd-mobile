#![allow(unexpected_cfgs)]

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

use std::{fmt, fs::OpenOptions, io, os::fd::AsRawFd, path::Path, time::Duration};

use bitcoincore_rpc::RpcApi;
use fedimint_core::{
    anyhow::{self, ensure},
    fedimint_build_code_version_env,
};
use flutter_rust_bridge::frb;

fn redirect_output(log_file_path: &Path) -> io::Result<()> {
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_file_path)?;

    let fd = file.as_raw_fd();

    // Duplicate file descriptor to stdout (fd 1) and stderr (fd 2)
    unsafe {
        libc::dup2(fd, libc::STDOUT_FILENO);
        libc::dup2(fd, libc::STDERR_FILENO);
    }

    // Optional: If you're using `println!`, flush stdout explicitly sometimes
    println!("Redirected stdout and stderr to {:?}", log_file_path);
    Ok(())
}

#[derive(Eq, PartialEq)]
enum NetworkType {
    Mutinynet,
    Regtest,
    Mainnet,
}

impl fmt::Display for NetworkType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            NetworkType::Mutinynet => "signet",
            NetworkType::Regtest => "regtest",
            NetworkType::Mainnet => "bitcoin",
        };
        write!(f, "{}", s)
    }
}

#[frb]
pub async fn start_fedimintd_esplora(
    db_path: String,
    network_type: NetworkType,
    esplora_url: String,
) -> anyhow::Result<()> {
    let fedimintd_dir = Path::new(&db_path).join("fedimintd_mobile");

    // Create the directory if it doesn't exist
    std::fs::create_dir_all(&fedimintd_dir)?;

    let log_path = fedimintd_dir.join("fedimintd.txt");
    redirect_output(&log_path)?;
    println!("Starting fedimintd...");
    std::env::set_var("FM_ENABLE_IROH", "true");
    std::env::set_var("FM_DATA_DIR", fedimintd_dir);
    std::env::set_var("FM_BITCOIN_NETWORK", &format!("{network_type}"));
    std::env::set_var("FM_ESPLORA_URL", esplora_url);
    // Not sure if this is currently necessary
    std::env::set_var("FM_BIND_UI", "0.0.0.0:8175");
    fedimintd::run(
        fedimintd::default_modules,
        fedimint_build_code_version_env!(),
        None,
    )
    .await
}

#[frb]
pub async fn start_fedimintd_bitcoind(
    db_path: String,
    network_type: NetworkType,
    username: String,
    password: String,
    url: String,
) -> anyhow::Result<()> {
    let fedimintd_dir = Path::new(&db_path).join("fedimintd_mobile");

    // Create the directory if it doesn't exist
    std::fs::create_dir_all(&fedimintd_dir)?;

    let log_path = fedimintd_dir.join("fedimintd.txt");
    redirect_output(&log_path)?;
    println!("Starting fedimintd...");
    std::env::set_var("FM_ENABLE_IROH", "true");
    std::env::set_var("FM_DATA_DIR", fedimintd_dir);
    std::env::set_var("FM_BITCOIN_NETWORK", &format!("{network_type}"));
    std::env::set_var("FM_BITCOIND_USERNAME", username);
    std::env::set_var("FM_BITCOIND_PASSWORD", password);
    std::env::set_var("FM_BITCOIND_URL", url);
    // Not sure if this is currently necessary
    std::env::set_var("FM_BIND_UI", "0.0.0.0:8175");
    fedimintd::run(
        fedimintd::default_modules,
        fedimint_build_code_version_env!(),
        None,
    )
    .await
}

#[frb]
pub async fn test_esplora(esplora_url: String, network: NetworkType) -> anyhow::Result<()> {
    let client = esplora_client::Builder::new(&esplora_url)
        .max_retries(0)
        .build_async()?;
    let genesis_hash = client.get_block_hash(0).await?;
    let esplora_network = match genesis_hash.to_string().as_str() {
        // Mainnet
        "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f" => NetworkType::Mainnet,
        // Mutinynet
        "00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6" => {
            NetworkType::Mutinynet
        }
        // Regtest
        "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206" => NetworkType::Regtest,
        h => {
            println!("Unsupported block hash: {h}");
            return Err(anyhow::anyhow!("Unsupported genesis block hash"));
        }
    };
    ensure!(network == esplora_network);
    Ok(())
}

#[frb]
pub async fn test_bitcoind(
    username: String,
    password: String,
    url: String,
    network: NetworkType,
) -> anyhow::Result<()> {
    let builder = bitcoincore_rpc::jsonrpc::simple_http::Builder::new()
        .url(&url)?
        .auth(username, Some(password))
        .timeout(Duration::from_secs(45));
    let client = bitcoincore_rpc::jsonrpc::Client::with_transport(builder.build());
    let json_rpc_client = bitcoincore_rpc::Client::from_jsonrpc(client);
    let blockhash = json_rpc_client.get_block_hash(0)?;
    let bitcoind_network = match blockhash.to_string().as_str() {
        // Mainnet
        "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f" => NetworkType::Mainnet,
        // Mutinynet
        "00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6" => {
            NetworkType::Mutinynet
        }
        // Regtest
        "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206" => NetworkType::Regtest,
        h => {
            println!("Unsupported block hash: {h}");
            return Err(anyhow::anyhow!("Unsupported genesis block hash"));
        }
    };
    ensure!(network == bitcoind_network);
    Ok(())
}
