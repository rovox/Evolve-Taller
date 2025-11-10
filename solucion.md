ayudame a corregir problemas que tengo con mi lanzamiento de ev-tools , quisiera usar esta wallet porque ya tiene token de TIA que puedo usar , ahi esta igual la llave que usa esa cuenta donde ya agregue 10 TIA en la testnet mocha-4
using directory:  /home/celestia/keys
- address: celestia1sg7krnvvsg3ctyeytc87jzptdda8v3a5fa5cje
  name: my_celes_key
  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Ak8DeF28akNjX7DmQ5D3RkGVh69TfTQLWIE79CTCHc5g"}'
  type: local
Quiero realizar una configuracion primordial para desarrollar cambios , porque tengo errores luego de iniciar la nueva implementacion con los nuevos comandos que estan en proceso.txt , me sale este mensaje en celestia-node , que es el servicio que mas falla , segun parece no tiene sincronizado la altura o datos de la red y por eso queda obsoleto o eso es lo que me dijo una ia , puedes revisar de manera critica y decirme cual es el problema:
docker compose logs --follow da


celestia-node  | 🚀 [2025-11-08 14:00:36] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:36] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:00:36] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:36] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:00:37.081Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:00:37.081Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:00:37.089Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:00:37] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:37] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:00:37] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:00:37.512Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:00:37.512Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:00:37.525Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:00:37] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:37] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:00:37] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:37] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:00:38.054Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:00:38.054Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:00:38.061Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:00:38] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:38] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:38] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | 🚀 [2025-11-08 14:00:39] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:39] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:00:39] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:39] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:00:39.808Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:00:39.808Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:00:39.815Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:00:41] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:41] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:41] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | 🚀 [2025-11-08 14:00:45] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:45] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ⚙️  [2025-11-08 14:00:45] CONFIG: Adding TxWorkerAccounts = 8 to [State] section
celestia-node  | ✅ [2025-11-08 14:00:45] SUCCESS: TxWorkerAccounts added to [State] section
celestia-node  | 🚀 [2025-11-08 14:00:45] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:45] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:00:45.156Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:00:45.156Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:00:45.169Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:00:51] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:00:51] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ⚙️  [2025-11-08 14:00:51] CONFIG: Adding TxWorkerAccounts = 8 to [State] section
celestia-node  | ✅ [2025-11-08 14:00:51] SUCCESS: TxWorkerAccounts added to [State] section
celestia-node  | 🚀 [2025-11-08 14:00:51] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:00:51] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:00:51.939Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:00:51.939Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:00:51.947Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:01:04] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:01:04] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:01:04] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | 🚀 [2025-11-08 14:01:30] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:01:30] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:01:30] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:01:30] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:01:31.032Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:01:31.032Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:01:31.048Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:02:22] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:02:22] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:02:22] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:02:22] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:02:22.611Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:02:22.611Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:02:22.619Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:03:22] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:03:22] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:03:22] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:03:22] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:03:22.966Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:03:22.966Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:03:22.980Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:00] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:00] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ⚙️  [2025-11-08 14:04:00] CONFIG: Adding TxWorkerAccounts = 8 to [State] section
celestia-node  | ✅ [2025-11-08 14:04:00] SUCCESS: TxWorkerAccounts added to [State] section
celestia-node  | 🚀 [2025-11-08 14:04:00] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:00.518Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:00.518Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:00.525Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:00] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:00] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:04:00] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:00] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:01.029Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:01.029Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:01.037Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:01] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:01] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:04:01] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:01] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:01.615Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:01.615Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:01.625Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:02] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:02] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ⚙️  [2025-11-08 14:04:02] CONFIG: Adding TxWorkerAccounts = 8 to [State] section
celestia-node  | ✅ [2025-11-08 14:04:02] SUCCESS: TxWorkerAccounts added to [State] section
celestia-node  | 🚀 [2025-11-08 14:04:02] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:02] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:02.475Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:02.475Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:02.482Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:03] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:03] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:04:03] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:03] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:03.688Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:03.688Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:03.696Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:05] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:05] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:04:05] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:05] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:05.676Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:05.676Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:05.686Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:09] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:09] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ⚙️  [2025-11-08 14:04:09] CONFIG: Adding TxWorkerAccounts = 8 to [State] section
celestia-node  | ✅ [2025-11-08 14:04:09] SUCCESS: TxWorkerAccounts added to [State] section
celestia-node  | 🚀 [2025-11-08 14:04:09] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:09] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:09.272Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:09.272Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:09.280Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized
celestia-node  | 🚀 [2025-11-08 14:04:15] INIT: Starting Celestia Light Node initialization
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: Light node config path: /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: DA Core IP: celestia-app
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: DA Core Port: 9090
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: DA Network: mocha-4
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: DA RPC Port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: DA Trusted Height: 8727828
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: DA Trusted Hash: 38B4A5836993CC004B41D6B1AB76CD1207ACE67D53474FAFD8F6FFFF0C641681
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: Config file already exists at /home/celestia/config.toml
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: Skipping initialization - light node already configured
celestia-node  | ⚙️  [2025-11-08 14:04:15] CONFIG: Ensuring TxWorkerAccounts is set to 8 in [State] section
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: TxWorkerAccounts already set to 8, no changes needed
celestia-node  | 🚀 [2025-11-08 14:04:15] INIT: Starting Celestia light node
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: Light node will be accessible on RPC port: 26658
celestia-node  | ℹ️  [2025-11-08 14:04:15] INFO: Starting with skip-auth enabled for RPC access
celestia-node  | 2025-11-08T14:04:16.073Z	WARN	rpc	rpc/flags.go:88	RPC authentication disabled (--rpc.skip-auth)
celestia-node  | 2025-11-08T14:04:16.073Z	INFO	module/pruner	pruner/flags.go:37	PRUNING MODE ENABLED. Node will prune blocks to save space.
celestia-node  | 2025-11-08T14:04:16.080Z	ERROR	node	nodebuilder/init.go:137	loading config	{"path": "/home/celestia", "err": "toml: line 14 (last key \"State.TxWorkerAccounts\"): Key 'State.TxWorkerAccounts' has already been defined."}
celestia-node  | Error: node: store is not initialized

----
## **Problema Principal Identificado**

El error crítico que está causando el fallo en bucle del `celestia-node` es:

```
toml: line 14 (last key "State.TxWorkerAccounts"): Key 'State.TxWorkerAccounts' has already been defined.
Error: node: store is not initialized
```

El problema **NO** es de sincronización de red como sugirió la IA anterior. El verdadero problema es que **el archivo `config.toml` tiene la clave `TxWorkerAccounts` duplicada**, lo cual genera un error de parsing del archivo TOML e impide que el nodo inicialice correctamente.

## **Causa Raíz**

Tu script de inicialización (`entrypoint.da.sh` o similar) está agregando repetidamente la configuración `TxWorkerAccounts = 8` al archivo de configuración cada vez que intenta arrancar, sin verificar primero si ya existe. Esto crea entradas duplicadas que rompen el formato TOML.

## **Solución Paso a Paso**

### **1. Detener todos los servicios**

```bash
cd ~/evolve-deployment/stacks/da-celestia
docker compose down
```

### **2. Limpiar el archivo de configuración corrupto**

Necesitas editar o regenerar el archivo `config.toml` del nodo Celestia. Primero, localiza dónde está montado:

```bash
# Ver los volúmenes montados
docker volume ls | grep celestia-node

# Inspeccionar el volumen
docker volume inspect da-celestia_celestia-node-data
```

Tienes dos opciones:

**Opción A: Eliminar y reinicializar (más limpio)**

```bash
# Eliminar el volumen del nodo (PERDERÁ DATOS DEL NODO, pero no las claves)
docker volume rm da-celestia_celestia-node-data

# Las claves están en otro volumen, verifícalo
docker volume ls | grep celestia
```

**Opción B: Editar manualmente el config.toml**

```bash
# Encontrar el config.toml en el sistema de archivos
# Normalmente está en el volumen Docker, necesitarás acceder así:

# Arrancar un contenedor temporal con el volumen montado
docker run -it --rm -v da-celestia_celestia-node-data:/data alpine sh

# Dentro del contenedor:
cd /data
vi config.toml  # o usa 'cat config.toml' para ver el contenido

# Busca la línea 14 y elimina las entradas duplicadas de TxWorkerAccounts
# Debe aparecer SOLO UNA VEZ en la sección [State]
```

### **3. Corregir el script de inicialización**

Debes modificar tu script de entrada para que no agregue `TxWorkerAccounts` duplicado. Busca en el archivo `entrypoint.da.sh` (o similar en `~/evolve-deployment/stacks/da-celestia/`) la sección que agrega esta configuración.

**Modificación sugerida en el script:**

Cambia la lógica de agregar `TxWorkerAccounts` para que verifique correctamente:

```bash
# En lugar de simplemente agregar, asegúrate de que verifica primero
if grep -q "^TxWorkerAccounts" "$CONFIG_FILE"; then
    echo "TxWorkerAccounts already configured"
else
    # Agregar SOLO si no existe
    sed -i '/\[State\]/a TxWorkerAccounts = 8' "$CONFIG_FILE"
fi
```

El problema actual es que tu script probablemente usa algo como:

```bash
# Esto es MALO - agrega sin verificar
sed -i '/\[State\]/a TxWorkerAccounts = 8' "$CONFIG_FILE"
```

### **4. Reiniciar con configuración limpia**

```bash
# Después de corregir el script
cd ~/evolve-deployment/stacks/da-celestia
docker compose up -d

# Monitorear los logs
docker compose logs -f celestia-node
```

### **5. Verificar que el nodo arranca correctamente**

Deberías ver logs como:

```
INFO: Starting celestia light node
INFO: Node started successfully
```

En lugar del error de `loading config` que estabas viendo.

## **Sobre tu Wallet**

Tu wallet `celestia1sg7krnvvsg3ctyeytc87jzptdda8v3a5fa5cje` con los 10 TIA está correcta y lista para usar. El problema NO es la wallet ni los fondos, sino únicamente la configuración corrupta del nodo.

## **Verificación Post-Corrección**

Una vez corregido, verifica:

```bash
# Estado del nodo
docker compose ps

# Verificar conectividad
curl -s http://localhost:26658/header | jq .

# Ver que ya no hay errores de config
docker compose logs celestia-node | grep ERROR
```

Si sigues este proceso, tu nodo debería arrancar correctamente y poder usar los 10 TIA que ya tienes en la wallet para publicar datos en Celestia.

[1](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/125552518/35858423-c399-45d5-b91c-510ac7aca040/proceso.txt)
