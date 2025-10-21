# Changelog

## [1.9.0](https://github.com/NethermindEth/simple-surge-node/compare/v1.8.1...v1.9.0) (2025-10-21)


### Features

* add additional raiko configs and remove devnet machine details ([7525184](https://github.com/NethermindEth/simple-surge-node/commit/75251840269bd46696d0d5e44be1cbfdce282853))
* add blockscout to docker compose and add jwt, chainspec needed for starting L2 ([3bff50a](https://github.com/NethermindEth/simple-surge-node/commit/3bff50aec16718f1fd6d2b6b88656429e2e2866d))
* add bridge ui as submodule ([c136474](https://github.com/NethermindEth/simple-surge-node/commit/c136474a070308cfc8ff5c517043a680f9c6ef68))
* add bridge ui as submodule ([18b8d8c](https://github.com/NethermindEth/simple-surge-node/commit/18b8d8cd2bcb95ea2d046beb27e689a056107c8e))
* add echo informing of the proposer being disabled before 'sleep infinity' ([#139](https://github.com/NethermindEth/simple-surge-node/issues/139)) ([541c04b](https://github.com/NethermindEth/simple-surge-node/commit/541c04b8348e2ad39b87dba3546aeebd9d604529))
* add l2 protocol deployment to docker compose and update env vars ([3307d44](https://github.com/NethermindEth/simple-surge-node/commit/3307d44b301bf316223f2935905cfa2b81950090))
* add L2 SCs deployer and draft of L1 SCs deployer ([b42fbf2](https://github.com/NethermindEth/simple-surge-node/commit/b42fbf2159ed47415d257058a7904286dfef2f5e))
* add monitoring for nm EL ([291c698](https://github.com/NethermindEth/simple-surge-node/commit/291c698b9a6e5f9e0caa9229c7ebd3f1b66960be))
* add multiprover configs ([66a04e9](https://github.com/NethermindEth/simple-surge-node/commit/66a04e90c94e4ddfc2c572f3b4ec45399286dfe8))
* add proposer wrapper, update services sequence and modify spamo… ([f7c6127](https://github.com/NethermindEth/simple-surge-node/commit/f7c612779bd7afd0c1a3b75d7b599c59abdc1bea))
* add proposer wrapper, update services sequence and modify spamoor configs ([0bfe4e6](https://github.com/NethermindEth/simple-surge-node/commit/0bfe4e651e9b349780ea1bf4e64692a9e3c829f2))
* add raiko specfic env vars to script ([38e072b](https://github.com/NethermindEth/simple-surge-node/commit/38e072b41f4dad3133e8f52e36b56b209583e153))
* add set erc20 vault address ([c342eaf](https://github.com/NethermindEth/simple-surge-node/commit/c342eaf60f51195e06732bf07e3a2bda496f4b52))
* add spamoor for L2 stack ([#23](https://github.com/NethermindEth/simple-surge-node/issues/23)) ([7470a01](https://github.com/NethermindEth/simple-surge-node/commit/7470a011a168ba0eac5bc6ae656283d3e6e3286c))
* add standardised labels for external source metrics and logs ([67f5f15](https://github.com/NethermindEth/simple-surge-node/commit/67f5f15783ee22eeb03f37c04d8e4cb86aff17f4))
* add standardised labels for external source metrics and logs ([a02c279](https://github.com/NethermindEth/simple-surge-node/commit/a02c2796dc59d1f1c26dfa7c517493a70decd2ba))
* add testnet genesis and chainspec ([933b896](https://github.com/NethermindEth/simple-surge-node/commit/933b89606dc6f43654146bc9de40d00e0e359e3e))
* add update-env.sh util script ([#106](https://github.com/NethermindEth/simple-surge-node/issues/106)) ([0a15475](https://github.com/NethermindEth/simple-surge-node/commit/0a15475e43c6d68bf053cce1f0ed277cd9149ea8))
* **all:** add default `proposeBlockTxGasTipCap` flag value for proposers ([#110](https://github.com/NethermindEth/simple-surge-node/issues/110)) ([6b084e2](https://github.com/NethermindEth/simple-surge-node/commit/6b084e26be97b9c3566d94ed0eceaf33e88103e4))
* **all:** initial commit ([#1](https://github.com/NethermindEth/simple-surge-node/issues/1)) ([c44176c](https://github.com/NethermindEth/simple-surge-node/commit/c44176c6c5c017ceb5d945d3a8d348ee2b67d30a))
* **all:** update configurations for alpha-5 testnet ([#121](https://github.com/NethermindEth/simple-surge-node/issues/121)) ([3f5347e](https://github.com/NethermindEth/simple-surge-node/commit/3f5347e9a308ee37a3c7861d02b5705e7c4b66a7))
* **alpha-3:** add more bootnodes ([#58](https://github.com/NethermindEth/simple-surge-node/issues/58)) ([76de101](https://github.com/NethermindEth/simple-surge-node/commit/76de101a175c9185421da22579f90dabb9ea1f38))
* **alpha-4:** add Eldfell network configs ([#67](https://github.com/NethermindEth/simple-surge-node/issues/67)) ([d34b96b](https://github.com/NethermindEth/simple-surge-node/commit/d34b96b062d19a0562398202aca2b597e81f6a5b))
* **alpha-6:** add `Katla` network configs ([#158](https://github.com/NethermindEth/simple-surge-node/issues/158)) ([bf1d2a2](https://github.com/NethermindEth/simple-surge-node/commit/bf1d2a2b59bcdb6f702d3cb56ac6781ed134ea88))
* apply assignmenthook update for hekla  ([#301](https://github.com/NethermindEth/simple-surge-node/issues/301)) ([db01c11](https://github.com/NethermindEth/simple-surge-node/commit/db01c113d8952c888d8031afc50d8d9bf2969493))
* **chore:** update docker-compose configurations ([#53](https://github.com/NethermindEth/simple-surge-node/issues/53)) ([3ee89e7](https://github.com/NethermindEth/simple-surge-node/commit/3ee89e7bd47dfc0c640298641e434f253169eec9))
* docker-compose.yml formatting ([#225](https://github.com/NethermindEth/simple-surge-node/issues/225)) ([0ca3155](https://github.com/NethermindEth/simple-surge-node/commit/0ca3155fc29840857204e6c0a32e73eb6eafb78f))
* **eldfell:** add `PROVE_UNASSIGNED_BLOCKS` env ([#69](https://github.com/NethermindEth/simple-surge-node/issues/69)) ([1d6e1cd](https://github.com/NethermindEth/simple-surge-node/commit/1d6e1cd5be8fe55568ff349cf0ca3ef16440f835))
* **eldfell:** increase zkevm-chain-rpcd wait timeout ([#73](https://github.com/NethermindEth/simple-surge-node/issues/73)) ([d9e6586](https://github.com/NethermindEth/simple-surge-node/commit/d9e6586bbb941095e60ac6e506622d9a7139df2a))
* **eldfell:** update `PORT_L3_EXECTION_ENGINE_HTTP` && `PORT_L3_EXECTION_ENGINE_WS` ([#68](https://github.com/NethermindEth/simple-surge-node/issues/68)) ([3a75489](https://github.com/NethermindEth/simple-surge-node/commit/3a75489a28b3c3cde17462f0bd4fdef04a680c01))
* **eldfell:** update default bootnodes ([#98](https://github.com/NethermindEth/simple-surge-node/issues/98)) ([2b8d662](https://github.com/NethermindEth/simple-surge-node/commit/2b8d6620dc2e8ae146cc9812ca02fc9bfe96ad24))
* **eldfell:** update service names ([#70](https://github.com/NethermindEth/simple-surge-node/issues/70)) ([e7cb642](https://github.com/NethermindEth/simple-surge-node/commit/e7cb6425bbf7d1c5972888c33f1bd70d573c1c96))
* **env:** add TxMgr flag annotations ([#334](https://github.com/NethermindEth/simple-surge-node/issues/334)) ([dd9322f](https://github.com/NethermindEth/simple-surge-node/commit/dd9322f10f4d1fa7bc4e46daed9a5accb0581486))
* **env:** update Hekla && mainnet bootnodes ([#332](https://github.com/NethermindEth/simple-surge-node/issues/332)) ([0955f43](https://github.com/NethermindEth/simple-surge-node/commit/0955f43191fa62175d89a911b6d3085424b15d85))
* **env:** use golden touch account as `L2_THROWAWAY_BLOCK_BUILDER` ([#12](https://github.com/NethermindEth/simple-surge-node/issues/12)) ([fc4de37](https://github.com/NethermindEth/simple-surge-node/commit/fc4de37d2b16a9c3b2c2c963bf4809395cc7482f))
* fetch registration data from the provers automatically ([fa39457](https://github.com/NethermindEth/simple-surge-node/commit/fa3945714d63586bc3912f9996b4a2e90a40874f))
* **grimsvotn:** add `DISABLE_P2P_SYNC` option ([#57](https://github.com/NethermindEth/simple-surge-node/issues/57)) ([55cc163](https://github.com/NethermindEth/simple-surge-node/commit/55cc16384591b5b84f14f0ce3ea55a7a36125ebe))
* **grimsvotn:** update A3 zkevm-chain-prover-rpcd memory limit ([#95](https://github.com/NethermindEth/simple-surge-node/issues/95)) ([836d217](https://github.com/NethermindEth/simple-surge-node/commit/836d217185be902d769cff2f7a2b0ca536d75e44))
* **grímsvötn:** update p2p sync timeout config ([#56](https://github.com/NethermindEth/simple-surge-node/issues/56)) ([c1b5cd0](https://github.com/NethermindEth/simple-surge-node/commit/c1b5cd02bff6f8502b0a842ab2b89f72babfcbec))
* guest_data retrieval logic updated to match updated logic in raiko ([c19ca4f](https://github.com/NethermindEth/simple-surge-node/commit/c19ca4fb0e1ac4c3f3826f447f19b0c1b9f954fb))
* handle unix signals ([#224](https://github.com/NethermindEth/simple-surge-node/issues/224)) ([247ef63](https://github.com/NethermindEth/simple-surge-node/commit/247ef6382e17f9f1aa381440348dc4d13e3c2558))
* **hekla:** bump client and l2ee version ([#326](https://github.com/NethermindEth/simple-surge-node/issues/326)) ([2f6c06e](https://github.com/NethermindEth/simple-surge-node/commit/2f6c06e0384f9bc7127795146d0d026558a4020e))
* **hekla:** bump Hekla client tag ([#337](https://github.com/NethermindEth/simple-surge-node/issues/337)) ([b575679](https://github.com/NethermindEth/simple-surge-node/commit/b575679af1262f72426ada160596b586cf3cff99))
* **hekla:** introduce `--gpo.ignoreprice` flag ([#247](https://github.com/NethermindEth/simple-surge-node/issues/247)) ([e5221f2](https://github.com/NethermindEth/simple-surge-node/commit/e5221f24a418cb6fa49b95a41c15edcedefa0779))
* **hekla:** modify `simple-taiko-node` for hekla  ([#205](https://github.com/NethermindEth/simple-surge-node/issues/205)) ([b0a1b21](https://github.com/NethermindEth/simple-surge-node/commit/b0a1b211a8d1e6610ea3ad8c31594faba4adc37d))
* **hekla:** update default `TX_GAS_LIMIT` config ([#209](https://github.com/NethermindEth/simple-surge-node/issues/209)) ([e75f5f0](https://github.com/NethermindEth/simple-surge-node/commit/e75f5f05027c59e17d0b31122119ede035f6f2b6))
* include staging env chainspec ([256d41e](https://github.com/NethermindEth/simple-surge-node/commit/256d41ecb1e98d2fc9e91662b6c01f63ba0b6e97))
* **jolnir:** update default gas limit configurations ([#129](https://github.com/NethermindEth/simple-surge-node/issues/129)) ([96c48a5](https://github.com/NethermindEth/simple-surge-node/commit/96c48a5b2c3a5b8f42e5a29305482de46644305b))
* **katla:** improve `start-zkevm-chain-rpcd.sh` ([#164](https://github.com/NethermindEth/simple-surge-node/issues/164)) ([e56a6e7](https://github.com/NethermindEth/simple-surge-node/commit/e56a6e754774f703817ea5213968c4c6f576bcd0))
* **log:** add `PROVER IS DISABLED` log ([#178](https://github.com/NethermindEth/simple-surge-node/issues/178)) ([25af49c](https://github.com/NethermindEth/simple-surge-node/commit/25af49c14687cc8345394f690f5c94ce8aa4c6ae))
* **mainnet:** bump client version ([#304](https://github.com/NethermindEth/simple-surge-node/issues/304)) ([67bcff0](https://github.com/NethermindEth/simple-surge-node/commit/67bcff0fb5abb3a00ac6abea07b2d18e8874c618))
* **mainnet:** bump client version ([#336](https://github.com/NethermindEth/simple-surge-node/issues/336)) ([9166881](https://github.com/NethermindEth/simple-surge-node/commit/9166881fb0e9bb6025910f861143cc0720eba76e))
* **mainnet:** bump version ([#341](https://github.com/NethermindEth/simple-surge-node/issues/341)) ([ec5868f](https://github.com/NethermindEth/simple-surge-node/commit/ec5868f1f2ad6585193148b48f5ae2a32cdc9055))
* **mainnet:** update mainnet configs ([#276](https://github.com/NethermindEth/simple-surge-node/issues/276)) ([ebe5bd7](https://github.com/NethermindEth/simple-surge-node/commit/ebe5bd726915c3ff17c0f9c8b7f6c5f70e826515))
* nethermind EL and SGX prover setup ([58bf89b](https://github.com/NethermindEth/simple-surge-node/commit/58bf89bd73152117a8dee4175b5750fcb8593183))
* new branch for SC deployments, deposit bonds and L2 setup ([ad45bda](https://github.com/NethermindEth/simple-surge-node/commit/ad45bda48e0a09ec64e7e7a2e24391746989ff40))
* **node:** set locals in node ([#92](https://github.com/NethermindEth/simple-surge-node/issues/92)) ([08a5b0d](https://github.com/NethermindEth/simple-surge-node/commit/08a5b0d132bd16646dc8c10ee575ed0978f45a4c))
* **proposer:** proposer can only propose local transactions ([#91](https://github.com/NethermindEth/simple-surge-node/issues/91)) ([8ba42aa](https://github.com/NethermindEth/simple-surge-node/commit/8ba42aa089d356ea61f882f9dfc2a0091bde2476))
* **proposer:** Proposer gas limit + script refactor ([#101](https://github.com/NethermindEth/simple-surge-node/issues/101)) ([17f1d0c](https://github.com/NethermindEth/simple-surge-node/commit/17f1d0c495e146b8668c77e6c225605f586da4c3))
* **proposer:** remove unused `BLOCK_BUILDER_TIP` ([#309](https://github.com/NethermindEth/simple-surge-node/issues/309)) ([f11e6be](https://github.com/NethermindEth/simple-surge-node/commit/f11e6be27c8da1662154a0b06430a86f11ab6f1f))
* **proposer:** rm tier fee ([#310](https://github.com/NethermindEth/simple-surge-node/issues/310)) ([aaf2ce0](https://github.com/NethermindEth/simple-surge-node/commit/aaf2ce0665f3de8d69947d44ef8c7fa1521ee9b0))
* **proposer:** support epoch.minTip ([#316](https://github.com/NethermindEth/simple-surge-node/issues/316)) ([e8c1f9a](https://github.com/NethermindEth/simple-surge-node/commit/e8c1f9a836865336149839b31e4f4529d13290c9))
* **proposer:** update proposer RPC config temporarily ([#26](https://github.com/NethermindEth/simple-surge-node/issues/26)) ([23eb266](https://github.com/NethermindEth/simple-surge-node/commit/23eb266addf42fdd9e80ca2c7d66e400fc38c5dd))
* **proposer:** wait receipt timeout flags + refactor prover scripts ([#104](https://github.com/NethermindEth/simple-surge-node/issues/104)) ([e76acb9](https://github.com/NethermindEth/simple-surge-node/commit/e76acb94f888863d825b2c3f6c5be1c393552cac))
* **prover,proposer,driver:** bump  client version ([#330](https://github.com/NethermindEth/simple-surge-node/issues/330)) ([ce53ce2](https://github.com/NethermindEth/simple-surge-node/commit/ce53ce22a63069adf5c84c01769117127b7e5403))
* **prover,proposer,driver:** bump l2ee and driver versions ([#329](https://github.com/NethermindEth/simple-surge-node/issues/329)) ([6cfd9f1](https://github.com/NethermindEth/simple-surge-node/commit/6cfd9f11197500b304038e8acd10ac4008e9379f))
* **prover:** add proof skip size config for L3 ([#118](https://github.com/NethermindEth/simple-surge-node/issues/118)) ([569592a](https://github.com/NethermindEth/simple-surge-node/commit/569592a0c3d404a3fbfba99668b2cddd3b379429))
* **prover:** add prove block tx gas limit flag  ([#115](https://github.com/NethermindEth/simple-surge-node/issues/115)) ([42d62bc](https://github.com/NethermindEth/simple-surge-node/commit/42d62bc24b074b5c3ccdc79b227963d4fbaee1d3))
* **prover:** remove unnecesary env in hekla .env.sample and fix ([#325](https://github.com/NethermindEth/simple-surge-node/issues/325)) ([0db06a8](https://github.com/NethermindEth/simple-surge-node/commit/0db06a8835bd7ca720865c709ee0e711c3350cb2))
* **prover:** support running node and sgx prover on different servers ([#221](https://github.com/NethermindEth/simple-surge-node/issues/221)) ([e84507a](https://github.com/NethermindEth/simple-surge-node/commit/e84507acf1a280b2838f66b00e1948eba88c0f0e))
* **prover:** update version of prover in hekla ([#323](https://github.com/NethermindEth/simple-surge-node/issues/323)) ([8ecd3bc](https://github.com/NethermindEth/simple-surge-node/commit/8ecd3bc7f9f9591fe448e044f7a48ca85a45d28c))
* Readme update ([#13](https://github.com/NethermindEth/simple-surge-node/issues/13)) ([c8d11d2](https://github.com/NethermindEth/simple-surge-node/commit/c8d11d220e8c18bfb1620e33a8f751c7447fda78))
* remove unused configs ([#305](https://github.com/NethermindEth/simple-surge-node/issues/305)) ([073bf24](https://github.com/NethermindEth/simple-surge-node/commit/073bf24be6557fcc80968b3ff24bd94de17f91c7))
* **repo:** add editorconfig ([#320](https://github.com/NethermindEth/simple-surge-node/issues/320)) ([bc5a9d0](https://github.com/NethermindEth/simple-surge-node/commit/bc5a9d00d6aad03d2abc21de084fdf442781edab))
* **repo:** enable OpenAI-based review ([#52](https://github.com/NethermindEth/simple-surge-node/issues/52)) ([6d0d863](https://github.com/NethermindEth/simple-surge-node/commit/6d0d863b1341ee158da946ffa2c78d08afcc65c6))
* rm useless config ([#281](https://github.com/NethermindEth/simple-surge-node/issues/281)) ([eebfffa](https://github.com/NethermindEth/simple-surge-node/commit/eebfffa82ff7c1a5eeddbd549cc7371914ed323a))
* **script:** add condition to check requirement variables for proposer/prover ([#238](https://github.com/NethermindEth/simple-surge-node/issues/238)) ([fca0c9a](https://github.com/NethermindEth/simple-surge-node/commit/fca0c9ae061085f4d11b1abf9452b71f9ed58cbd))
* set default home dashboard ([#174](https://github.com/NethermindEth/simple-surge-node/issues/174)) ([63a9aa7](https://github.com/NethermindEth/simple-surge-node/commit/63a9aa7010b81da18e2a68dda767bf66e2020f05))
* start multiple `zkevm-chain` provers ([#94](https://github.com/NethermindEth/simple-surge-node/issues/94)) ([2d12441](https://github.com/NethermindEth/simple-surge-node/commit/2d12441c0743192701443c86bd337f463d609376))
* update and add hoodi testnet env ([7410a60](https://github.com/NethermindEth/simple-surge-node/commit/7410a6076324825da635f15f822f5fea7a127e8c))
* update default ports ([#89](https://github.com/NethermindEth/simple-surge-node/issues/89)) ([27b902e](https://github.com/NethermindEth/simple-surge-node/commit/27b902eee8dab2d1c3dea3a6fbb32b1907f6ab5f))
* update for updated protocols and taiko client ([4af7886](https://github.com/NethermindEth/simple-surge-node/commit/4af78860bd53f509b3f57f390424955c61ee992e))
* update for updated protocols and taiko client ([c1c3821](https://github.com/NethermindEth/simple-surge-node/commit/c1c38217e2de64bb7424e4447e1836530c01e1a0))
* update proposer annd prover flags and nethermind EL image ([8ddbc2c](https://github.com/NethermindEth/simple-surge-node/commit/8ddbc2c526b4baea06b734dee826ad95503837fd))
* update scripts to be more visually informative ([65b73a1](https://github.com/NethermindEth/simple-surge-node/commit/65b73a17dfbe568c9a81e71ad5d137e85f87556c))
* update sync timeout ([#59](https://github.com/NethermindEth/simple-surge-node/issues/59)) ([cfbc2a0](https://github.com/NethermindEth/simple-surge-node/commit/cfbc2a02b95304382c424dd2c752646799647bc8))
* update tags for Hekla / mainnet ([#340](https://github.com/NethermindEth/simple-surge-node/issues/340)) ([3884f86](https://github.com/NethermindEth/simple-surge-node/commit/3884f860aa33d94a4c24450388e8634f96d243af))
* update taiko client and devnet env for SC updates on force inclusion ([87e1c42](https://github.com/NethermindEth/simple-surge-node/commit/87e1c4245bdb7b3943220aaa9e6ced734daa18f4))
* update taiko client image ([8b5bdf1](https://github.com/NethermindEth/simple-surge-node/commit/8b5bdf1eb26abce8561d8a5568729d7528da4267))
* update taiko client image with BatchParams Encoding fix, add new version blockscout and tx spammer ([c7b0f2c](https://github.com/NethermindEth/simple-surge-node/commit/c7b0f2cdc1b1e0d5a95f255d78846c50eb6cabc6))
* update taiko-client image and specify prover private key usage ([0b4876a](https://github.com/NethermindEth/simple-surge-node/commit/0b4876a5f3618bad043ef9a6d0981b1e556f1294))
* update to pacaya fork ([a8306c8](https://github.com/NethermindEth/simple-surge-node/commit/a8306c8f4993a79efb9f6c2e003443a76c4889ba))
* update to pacaya fork ([49edab8](https://github.com/NethermindEth/simple-surge-node/commit/49edab8dbb7a14dc95e7d1735f473c208438f1ec))


### Bug Fixes

* add backwards compat for new env var and small typo ([#96](https://github.com/NethermindEth/simple-surge-node/issues/96)) ([f7610ad](https://github.com/NethermindEth/simple-surge-node/commit/f7610ad4902c2d23df45deab8678fe8d66d1b71e))
* add default value for `GETH_ADDITIONAL_ARGS` ([#267](https://github.com/NethermindEth/simple-surge-node/issues/267)) ([aec2678](https://github.com/NethermindEth/simple-surge-node/commit/aec2678258dcd6d1272e6bbd9f023129f06931c9))
* add env for sgx register ([22eff2b](https://github.com/NethermindEth/simple-surge-node/commit/22eff2be4140c3deb67cf562bf54cfa28670e1b9))
* add missing and wrong flags and env vars for prover relayer ([83fa487](https://github.com/NethermindEth/simple-surge-node/commit/83fa48769b5b49716d7d752c0bc5cce306fc894d))
* add missing L1_TAIKO_WRAPPER_ADDRESS to devnet env ([53c5268](https://github.com/NethermindEth/simple-surge-node/commit/53c52682545a3c08e5cd16557b6b09f2acb9b901))
* add risc0 guest data retrieval ([620c6ea](https://github.com/NethermindEth/simple-surge-node/commit/620c6ea9a199b343515af54118ab0f9e9e121221))
* **docker-compose:** make hard-coded prover's port dynamic ([#41](https://github.com/NethermindEth/simple-surge-node/issues/41)) ([8c08689](https://github.com/NethermindEth/simple-surge-node/commit/8c0868924adbb558fb2d6f2178923d95428b51d3))
* **docs:** correct IP format in `.env.sample` endpoints ([#170](https://github.com/NethermindEth/simple-surge-node/issues/170)) ([3bf68cd](https://github.com/NethermindEth/simple-surge-node/commit/3bf68cda84997082fb3ecdcc48d0aa668e4f9996))
* double quotation ([#312](https://github.com/NethermindEth/simple-surge-node/issues/312)) ([8d5be17](https://github.com/NethermindEth/simple-surge-node/commit/8d5be172de0b49f75cf15b7e36a2c6f3ae7f9536))
* **eldfell:** fix `--proveUnassignedBlocks` flag setting ([#109](https://github.com/NethermindEth/simple-surge-node/issues/109)) ([0a86e18](https://github.com/NethermindEth/simple-surge-node/commit/0a86e18dfa0a038f8d36c8793870326e8fd4e96e))
* **eldfell:** fix zkevm-chain-proverd port in prover relayer script ([#72](https://github.com/NethermindEth/simple-surge-node/issues/72)) ([dee982e](https://github.com/NethermindEth/simple-surge-node/commit/dee982e27ee8a14dac09bb6b084fef804a8cd9d4))
* **eldfell:** make zkevm-rpcd-chain port number explicit ([#71](https://github.com/NethermindEth/simple-surge-node/issues/71)) ([38d2114](https://github.com/NethermindEth/simple-surge-node/commit/38d2114ca1e68a70e574f129c7fa3e02677d3904))
* **eldfell:** update zkevm-chain-rpcd host ([#75](https://github.com/NethermindEth/simple-surge-node/issues/75)) ([5a63f47](https://github.com/NethermindEth/simple-surge-node/commit/5a63f47ca5fce97fc32cfc05fbbb4ac8d3e39beb))
* **eldfell:** Use correct env flag in start-prover-relayer.sh ([#79](https://github.com/NethermindEth/simple-surge-node/issues/79)) ([9c1cdba](https://github.com/NethermindEth/simple-surge-node/commit/9c1cdba5d730ae3cc5ba50656d797e3db18d28b1))
* **eldfell:** Use env variable for port assignment in start-zkevm-chain-rpcd.sh ([#77](https://github.com/NethermindEth/simple-surge-node/issues/77)) ([a1dfb6d](https://github.com/NethermindEth/simple-surge-node/commit/a1dfb6d26fa35e43a9e81dca1f720d67224272a0))
* **env:** fix sample env file formatting ([7c15a6d](https://github.com/NethermindEth/simple-surge-node/commit/7c15a6d790abd09471cc4aeb23bcc1144525b93e))
* **env:** Update for .env.sample.l3 ([#99](https://github.com/NethermindEth/simple-surge-node/issues/99)) ([4b6ab2a](https://github.com/NethermindEth/simple-surge-node/commit/4b6ab2af4020bbde30b0c863706e1c6e82c97b2d))
* **env:** update sample env files ([#90](https://github.com/NethermindEth/simple-surge-node/issues/90)) ([a62598d](https://github.com/NethermindEth/simple-surge-node/commit/a62598d7fb026fbf0fc9d07ba408ff98cde8942c))
* **grafana:** set `'Instant'` as default query type for instant metrics ([#251](https://github.com/NethermindEth/simple-surge-node/issues/251)) ([9201f1a](https://github.com/NethermindEth/simple-surge-node/commit/9201f1aabf73b6ee97cb093d3517cb634df43ee6))
* **grimsvotn:** fix `start-prover-relayer.sh` script ([#108](https://github.com/NethermindEth/simple-surge-node/issues/108)) ([f83afaa](https://github.com/NethermindEth/simple-surge-node/commit/f83afaa6936981e94cda328336db5a92641157f7))
* l3 grafana dashboard ([#88](https://github.com/NethermindEth/simple-surge-node/issues/88)) ([8f4e9ba](https://github.com/NethermindEth/simple-surge-node/commit/8f4e9bab90de80bdc886c2e32ef4b13ccc6d8333))
* **node:** Typo fix spelling EXECUTION .env and yml files ([#119](https://github.com/NethermindEth/simple-surge-node/issues/119)) ([d5f46aa](https://github.com/NethermindEth/simple-surge-node/commit/d5f46aab36f90d352b48929eeb91d19270525da3))
* **proposer,driver,prover:** bump version ([#343](https://github.com/NethermindEth/simple-surge-node/issues/343)) ([254fb8e](https://github.com/NethermindEth/simple-surge-node/commit/254fb8ef10bec85ec467dada37dc3b8b9968a003))
* **proposer:** check enabled before args ([#255](https://github.com/NethermindEth/simple-surge-node/issues/255)) ([d54b0dd](https://github.com/NethermindEth/simple-surge-node/commit/d54b0dd0205a2709b0505cf5cc791889a2cdbe7e))
* **proposer:** fix proposer var ([#256](https://github.com/NethermindEth/simple-surge-node/issues/256)) ([d9afb56](https://github.com/NethermindEth/simple-surge-node/commit/d9afb56f9beb7b8dc26d7f13c4d8795bede8f771))
* **prover:** reorder script args ([#204](https://github.com/NethermindEth/simple-surge-node/issues/204)) ([df19538](https://github.com/NethermindEth/simple-surge-node/commit/df19538417978c8f822fe1b71b46cbbd8a041ecf))
* remove prover from proposer profile ([a907fc8](https://github.com/NethermindEth/simple-surge-node/commit/a907fc81bd158f3121d4dc1dead5a0756244069d))
* **repo:** fix openAI review workflow ([#54](https://github.com/NethermindEth/simple-surge-node/issues/54)) ([d8896cf](https://github.com/NethermindEth/simple-surge-node/commit/d8896cf2c0e94fb1c0da36a1cb9b2df658f5c17e))
* **script:** use docker internal port ([#45](https://github.com/NethermindEth/simple-surge-node/issues/45)) ([1ef326a](https://github.com/NethermindEth/simple-surge-node/commit/1ef326a8afbdceee159f051b6c35d3277750cab0))
* set default ADMIN for proposer-wrapper-deployer ([4e2e037](https://github.com/NethermindEth/simple-surge-node/commit/4e2e0378778c3f3f6c5b85575f5b5aac55f52d65))
* set default gas limit for proposer-wrapper-deployer ([3be69d7](https://github.com/NethermindEth/simple-surge-node/commit/3be69d7052160f0e9c7d1d22d1a716e7cf5293ac))
* update addresses to fix failed to retrieve surge verifier address ([333bba1](https://github.com/NethermindEth/simple-surge-node/commit/333bba1cb8b85e9e25413d79863e16254f75ab47))
* update authorizeCaller cast command and deposit bond in proposer wrapper ([3c68be1](https://github.com/NethermindEth/simple-surge-node/commit/3c68be1f96ac62dfb863893fded4b76508efdb4e))
* update docker-compose.yml for better p2p configuration ([#258](https://github.com/NethermindEth/simple-surge-node/issues/258)) ([bce9544](https://github.com/NethermindEth/simple-surge-node/commit/bce95442c8e2840ece0daca4138eea26e8e50e22))
* update domain for set address services ([efeffa5](https://github.com/NethermindEth/simple-surge-node/commit/efeffa51b03cd8d78baab71f960cf8a483e1b1eb))
* update images ([adaad1d](https://github.com/NethermindEth/simple-surge-node/commit/adaad1d21d9cbcb35d1178f31d532965e7a62608))
* update L2 El port for prover relayer ([9fe1ee5](https://github.com/NethermindEth/simple-surge-node/commit/9fe1ee5d2e184add7edaf991e404cf6d9f2855a4))
* update monitoring services indentation ([d269b3d](https://github.com/NethermindEth/simple-surge-node/commit/d269b3dd2c8fc47c23dcff93bf9291e98580db35))
* update prover relayer to connect to the right L2 EL ([5a88fe5](https://github.com/NethermindEth/simple-surge-node/commit/5a88fe5852a63f747f5dc1558d0d759e40466068))
* update relayer flags to use env vars instead of fixed values ([1c4a225](https://github.com/NethermindEth/simple-surge-node/commit/1c4a22513d812b84b018ab86f2babf9f65031800))
* update set-signal-service-address-l2 ([187030e](https://github.com/NethermindEth/simple-surge-node/commit/187030ebd70fd3f8ace24361e42acbd3a0efa758))
* update surge specific env vars to avoid clash ([8abc31b](https://github.com/NethermindEth/simple-surge-node/commit/8abc31beb58a217dbff348a8f85ebdb2811e8235))
* update surge-l2-deployer to use main-pacaya-v1.6.1 image tag ([dba2bd4](https://github.com/NethermindEth/simple-surge-node/commit/dba2bd4fabfc5527e7653221bbfe6d8e44ed0904))


### Chores

* add comments for proposeBlock gas params ([#113](https://github.com/NethermindEth/simple-surge-node/issues/113)) ([89ff0df](https://github.com/NethermindEth/simple-surge-node/commit/89ff0dfc2e9167857a783fadb52e58e1139847cd))
* add warnings to env sample ([#87](https://github.com/NethermindEth/simple-surge-node/issues/87)) ([d9125d9](https://github.com/NethermindEth/simple-surge-node/commit/d9125d9118de55277746c7d3c8c382415cf45bbd))
* bump `taiko-client` tag ([#286](https://github.com/NethermindEth/simple-surge-node/issues/286)) ([d9a1df2](https://github.com/NethermindEth/simple-surge-node/commit/d9a1df2a51c33f47b3382bd9786ee6fdc4909021))
* bump taiko-client tag ([#283](https://github.com/NethermindEth/simple-surge-node/issues/283)) ([34b68b8](https://github.com/NethermindEth/simple-surge-node/commit/34b68b8d70e2c29ee6586823dfa1daf61c714f85))
* bump taiko-client tag ([#293](https://github.com/NethermindEth/simple-surge-node/issues/293)) ([5d703ee](https://github.com/NethermindEth/simple-surge-node/commit/5d703ee2db4dff5ad0c88fd216ad6ed3855f4bd6))
* **ci:** introduce `Close Inactive Issues` workflow ([#249](https://github.com/NethermindEth/simple-surge-node/issues/249)) ([02c27e9](https://github.com/NethermindEth/simple-surge-node/commit/02c27e9d5ac85838ca0948c9cc28a458a16154ab))
* **config:** update default configurations ([#9](https://github.com/NethermindEth/simple-surge-node/issues/9)) ([f19df61](https://github.com/NethermindEth/simple-surge-node/commit/f19df616b23d904580a3852d2fea7f7235a607c8))
* **docker-compose:** remove obsolete `docker-compose.yml` version ([#211](https://github.com/NethermindEth/simple-surge-node/issues/211)) ([1f3652f](https://github.com/NethermindEth/simple-surge-node/commit/1f3652fde00e5dd70733a984a56e11eee8d13030))
* **docker:** bump Hekla tags ([#338](https://github.com/NethermindEth/simple-surge-node/issues/338)) ([6abe049](https://github.com/NethermindEth/simple-surge-node/commit/6abe0490faae82aa6783df41ad668d42f0fc74a2))
* **docker:** update geth image ([#321](https://github.com/NethermindEth/simple-surge-node/issues/321)) ([246dbb3](https://github.com/NethermindEth/simple-surge-node/commit/246dbb3fd93e35a76d19eb985a6225b2448ce1a1))
* **docs:** fix typo in env var ([#15](https://github.com/NethermindEth/simple-surge-node/issues/15)) ([244a380](https://github.com/NethermindEth/simple-surge-node/commit/244a380449af963b8f52a72c5155b50fb56180af))
* **docs:** update README ([#3](https://github.com/NethermindEth/simple-surge-node/issues/3)) ([c5ec981](https://github.com/NethermindEth/simple-surge-node/commit/c5ec981658d631ba7c2c120af9a38a76d24cb2b4))
* **docs:** Update README.md ([8484e77](https://github.com/NethermindEth/simple-surge-node/commit/8484e7702ab2bca93ec09d910c230128d8c22b80))
* **env:** remove default value for `TX_GAS_LIMIT` ([#239](https://github.com/NethermindEth/simple-surge-node/issues/239)) ([31a38ad](https://github.com/NethermindEth/simple-surge-node/commit/31a38adb945c8c77c132b162f24fb0e042850846))
* **env:** update `.env` `TKO` -&gt; `TTKOj`  ([#128](https://github.com/NethermindEth/simple-surge-node/issues/128)) ([493b881](https://github.com/NethermindEth/simple-surge-node/commit/493b881431b778fdcd82ec5db0eb661ccb233615))
* **hekla:** bump client & taiko-geth image version ([#327](https://github.com/NethermindEth/simple-surge-node/issues/327)) ([09d77eb](https://github.com/NethermindEth/simple-surge-node/commit/09d77ebc61506cf6fb67fd60b7ffba4325ee8c6f))
* **hekla:** bump client & taiko-geth image version ([#328](https://github.com/NethermindEth/simple-surge-node/issues/328)) ([807926f](https://github.com/NethermindEth/simple-surge-node/commit/807926fb9f0c27a9dbc756d345ceb65a81fcfdf0))
* **image:** use `snaefellsjokull` tags ([#13](https://github.com/NethermindEth/simple-surge-node/issues/13)) ([99a4174](https://github.com/NethermindEth/simple-surge-node/commit/99a41741624a7021fb2adf2d10eb1a09f7c9dc48))
* **mainnet:** update a comment ([#288](https://github.com/NethermindEth/simple-surge-node/issues/288)) ([81c587f](https://github.com/NethermindEth/simple-surge-node/commit/81c587fbde246bcd2a04a243049efc52fb95c2cb))
* **main:** release 1.0.0 ([#266](https://github.com/NethermindEth/simple-surge-node/issues/266)) ([05a475b](https://github.com/NethermindEth/simple-surge-node/commit/05a475b09b653c29c86516840f8cea46783edfd0))
* **main:** release 1.2.0 ([#302](https://github.com/NethermindEth/simple-surge-node/issues/302)) ([1d0048c](https://github.com/NethermindEth/simple-surge-node/commit/1d0048ccb3666a3204e58d70ee12c21ebc4c7ea5))
* **main:** release 1.3.0 ([#306](https://github.com/NethermindEth/simple-surge-node/issues/306)) ([3399581](https://github.com/NethermindEth/simple-surge-node/commit/3399581b49ec00c661b148f4d3ab7d7f207c1799))
* **main:** release 1.4.0 ([#313](https://github.com/NethermindEth/simple-surge-node/issues/313)) ([e7d458c](https://github.com/NethermindEth/simple-surge-node/commit/e7d458c8cb0e4ae458f3f15f2a8121804f688034))
* **main:** release 1.5.0 ([#324](https://github.com/NethermindEth/simple-surge-node/issues/324)) ([c1b48a3](https://github.com/NethermindEth/simple-surge-node/commit/c1b48a3ebdca4e39ec26d17d908903ac0cca5af1))
* **main:** release 1.6.0 ([#331](https://github.com/NethermindEth/simple-surge-node/issues/331)) ([346e7ed](https://github.com/NethermindEth/simple-surge-node/commit/346e7edfe994d39c3eeaa97c9c1b1ff3c292f9cb))
* **main:** release 1.7.0 ([#333](https://github.com/NethermindEth/simple-surge-node/issues/333)) ([c7b6373](https://github.com/NethermindEth/simple-surge-node/commit/c7b63736af62b51aaa44160e3fc07ba0d5355fa3))
* **main:** release 1.8.0 ([#335](https://github.com/NethermindEth/simple-surge-node/issues/335)) ([2416c35](https://github.com/NethermindEth/simple-surge-node/commit/2416c3582188bd7ccfc12a32733e36c54b2391ea))
* **main:** release 1.8.1 ([#344](https://github.com/NethermindEth/simple-surge-node/issues/344)) ([a643db8](https://github.com/NethermindEth/simple-surge-node/commit/a643db85e84051f100ac69dd63f2e05041ea9032))
* **main:** Updating both .env.sample explaining how to use REST port. ([#303](https://github.com/NethermindEth/simple-surge-node/issues/303)) ([87474c5](https://github.com/NethermindEth/simple-surge-node/commit/87474c5debe99ab93b54fc953dfb0c6ebf4eaa25))
* update .env.sample ([#117](https://github.com/NethermindEth/simple-surge-node/issues/117)) ([8d02234](https://github.com/NethermindEth/simple-surge-node/commit/8d02234468a9cbad23d4554948e4b92b40d8c363))
* update .env.sample default value ([#64](https://github.com/NethermindEth/simple-surge-node/issues/64)) ([87fe5e5](https://github.com/NethermindEth/simple-surge-node/commit/87fe5e5c551d1573de4c3416ec61c6f3d525d813))
* update `zkevm-chain-prover-rpcd` volumes ([#39](https://github.com/NethermindEth/simple-surge-node/issues/39)) ([9bb2423](https://github.com/NethermindEth/simple-surge-node/commit/9bb24238b6d2e03a2e79918454ac32075f56e32b))
* update env sample comments ([#126](https://github.com/NethermindEth/simple-surge-node/issues/126)) ([b51ec97](https://github.com/NethermindEth/simple-surge-node/commit/b51ec973ead21cbd8da0b53db40d2f9070cda405))
* update nethermind EL image ([a4a53ae](https://github.com/NethermindEth/simple-surge-node/commit/a4a53ae53ab21037ac85765b6f61ac347d691e13))


### Documentation

* **askja:** update documents for Askja testnet ([#36](https://github.com/NethermindEth/simple-surge-node/issues/36)) ([837dab1](https://github.com/NethermindEth/simple-surge-node/commit/837dab13c8fa24286bf5ec3a85856278a5ea9d98))
* **eldfell:** update comments on `.env.sample.l3` ([#78](https://github.com/NethermindEth/simple-surge-node/issues/78)) ([f89aee4](https://github.com/NethermindEth/simple-surge-node/commit/f89aee4243c985103bf94344dc81d416e78cbf98))
* **env:** request to Update Comments for Clarity in Token Configuration ([#235](https://github.com/NethermindEth/simple-surge-node/issues/235)) ([f6aa035](https://github.com/NethermindEth/simple-surge-node/commit/f6aa035de3406c1140b906ef5ac9ba115b9e8228))
* **hekla:** update comment of `L1_BEACON_HTTP` ([#213](https://github.com/NethermindEth/simple-surge-node/issues/213)) ([3f6ea92](https://github.com/NethermindEth/simple-surge-node/commit/3f6ea924be68c7ade52dd68de67b588a01d49a44))
* **node:** change symbol ([#282](https://github.com/NethermindEth/simple-surge-node/issues/282)) ([e71c262](https://github.com/NethermindEth/simple-surge-node/commit/e71c2621c2c03830e6f15c63f3d152577540a112))
* **readme:** add faq section about errors ([#27](https://github.com/NethermindEth/simple-surge-node/issues/27)) ([13255b9](https://github.com/NethermindEth/simple-surge-node/commit/13255b9660afeecb4d6edf396b0252b98f8596c4))
* **readme:** add needed prerequisites ([#29](https://github.com/NethermindEth/simple-surge-node/issues/29)) ([d87b34b](https://github.com/NethermindEth/simple-surge-node/commit/d87b34b58446749ffb0507f6ddfdec8e9888c3b5))
* **readme:** add some FAQs ([#20](https://github.com/NethermindEth/simple-surge-node/issues/20)) ([98c8d89](https://github.com/NethermindEth/simple-surge-node/commit/98c8d89ca65c2e3e5195173bc517353aa9207efd))
* **readme:** Add steps description for Proposing ([#22](https://github.com/NethermindEth/simple-surge-node/issues/22)) ([69e8090](https://github.com/NethermindEth/simple-surge-node/commit/69e8090088bb4ff4bb04d26343158f7f59c63437))
* **readme:** fix the geth minimum requirements link ([#23](https://github.com/NethermindEth/simple-surge-node/issues/23)) ([99b8d29](https://github.com/NethermindEth/simple-surge-node/commit/99b8d297e052211e8c19a35efbef1758379d68d0))
* update .env.sample file for mainnet ([#291](https://github.com/NethermindEth/simple-surge-node/issues/291)) ([92592ff](https://github.com/NethermindEth/simple-surge-node/commit/92592ff09a6a2f31c3b89e5bcd2042116a1386ab))
* update comments on .env.sample ([#38](https://github.com/NethermindEth/simple-surge-node/issues/38)) ([1e8dc7d](https://github.com/NethermindEth/simple-surge-node/commit/1e8dc7d271153a948bd59ab8fedba6cbfcae879d))
* update readme with deprecation announcement ([#33](https://github.com/NethermindEth/simple-surge-node/issues/33)) ([381cee8](https://github.com/NethermindEth/simple-surge-node/commit/381cee8419777d892d617589fcb044f233529852))
* Update README.md ([#10](https://github.com/NethermindEth/simple-surge-node/issues/10)) ([f4560b8](https://github.com/NethermindEth/simple-surge-node/commit/f4560b88a9549f0783aa515367ac7999d8b72144))
* update to 2023 and rename LICENSE to LICENSE.md ([4049294](https://github.com/NethermindEth/simple-surge-node/commit/404929445574c5cdd02d89ca7a36ec31a8555aed))


### Workflow

* add release-please ([#265](https://github.com/NethermindEth/simple-surge-node/issues/265)) ([a0e4422](https://github.com/NethermindEth/simple-surge-node/commit/a0e4422ea8aa40a5d6594ea7994ede553df56519))
* **repo:** improving repo workflows/renaming ([#317](https://github.com/NethermindEth/simple-surge-node/issues/317)) ([589456b](https://github.com/NethermindEth/simple-surge-node/commit/589456b372378558804ed1ddd68ec0a9ab0c085d))

## [1.8.1](https://github.com/taikoxyz/simple-taiko-node/compare/v1.8.0...v1.8.1) (2024-10-24)


### Bug Fixes

* **proposer,driver,prover:** bump version ([#343](https://github.com/taikoxyz/simple-taiko-node/issues/343)) ([254fb8e](https://github.com/taikoxyz/simple-taiko-node/commit/254fb8ef10bec85ec467dada37dc3b8b9968a003))

## [1.8.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.7.0...v1.8.0) (2024-10-23)


### Features

* **env:** add TxMgr flag annotations ([#334](https://github.com/taikoxyz/simple-taiko-node/issues/334)) ([dd9322f](https://github.com/taikoxyz/simple-taiko-node/commit/dd9322f10f4d1fa7bc4e46daed9a5accb0581486))
* **hekla:** bump Hekla client tag ([#337](https://github.com/taikoxyz/simple-taiko-node/issues/337)) ([b575679](https://github.com/taikoxyz/simple-taiko-node/commit/b575679af1262f72426ada160596b586cf3cff99))
* **mainnet:** bump client version ([#336](https://github.com/taikoxyz/simple-taiko-node/issues/336)) ([9166881](https://github.com/taikoxyz/simple-taiko-node/commit/9166881fb0e9bb6025910f861143cc0720eba76e))
* **mainnet:** bump version ([#341](https://github.com/taikoxyz/simple-taiko-node/issues/341)) ([ec5868f](https://github.com/taikoxyz/simple-taiko-node/commit/ec5868f1f2ad6585193148b48f5ae2a32cdc9055))
* update tags for Hekla / mainnet ([#340](https://github.com/taikoxyz/simple-taiko-node/issues/340)) ([3884f86](https://github.com/taikoxyz/simple-taiko-node/commit/3884f860aa33d94a4c24450388e8634f96d243af))


### Chores

* **docker:** bump Hekla tags ([#338](https://github.com/taikoxyz/simple-taiko-node/issues/338)) ([6abe049](https://github.com/taikoxyz/simple-taiko-node/commit/6abe0490faae82aa6783df41ad668d42f0fc74a2))

## [1.7.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.6.0...v1.7.0) (2024-09-12)


### Features

* **env:** update Hekla && mainnet bootnodes ([#332](https://github.com/taikoxyz/simple-taiko-node/issues/332)) ([0955f43](https://github.com/taikoxyz/simple-taiko-node/commit/0955f43191fa62175d89a911b6d3085424b15d85))

## [1.6.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.5.0...v1.6.0) (2024-09-12)


### Features

* **prover,proposer,driver:** bump  client version ([#330](https://github.com/taikoxyz/simple-taiko-node/issues/330)) ([ce53ce2](https://github.com/taikoxyz/simple-taiko-node/commit/ce53ce22a63069adf5c84c01769117127b7e5403))

## [1.5.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.4.0...v1.5.0) (2024-09-11)


### Features

* **hekla:** bump client and l2ee version ([#326](https://github.com/taikoxyz/simple-taiko-node/issues/326)) ([2f6c06e](https://github.com/taikoxyz/simple-taiko-node/commit/2f6c06e0384f9bc7127795146d0d026558a4020e))
* **prover,proposer,driver:** bump l2ee and driver versions ([#329](https://github.com/taikoxyz/simple-taiko-node/issues/329)) ([6cfd9f1](https://github.com/taikoxyz/simple-taiko-node/commit/6cfd9f11197500b304038e8acd10ac4008e9379f))
* **prover:** remove unnecesary env in hekla .env.sample and fix ([#325](https://github.com/taikoxyz/simple-taiko-node/issues/325)) ([0db06a8](https://github.com/taikoxyz/simple-taiko-node/commit/0db06a8835bd7ca720865c709ee0e711c3350cb2))
* **prover:** update version of prover in hekla ([#323](https://github.com/taikoxyz/simple-taiko-node/issues/323)) ([8ecd3bc](https://github.com/taikoxyz/simple-taiko-node/commit/8ecd3bc7f9f9591fe448e044f7a48ca85a45d28c))


### Chores

* **hekla:** bump client & taiko-geth image version ([#327](https://github.com/taikoxyz/simple-taiko-node/issues/327)) ([09d77eb](https://github.com/taikoxyz/simple-taiko-node/commit/09d77ebc61506cf6fb67fd60b7ffba4325ee8c6f))
* **hekla:** bump client & taiko-geth image version ([#328](https://github.com/taikoxyz/simple-taiko-node/issues/328)) ([807926f](https://github.com/taikoxyz/simple-taiko-node/commit/807926fb9f0c27a9dbc756d345ceb65a81fcfdf0))

## [1.4.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.3.0...v1.4.0) (2024-07-18)


### Features

* **proposer:** support epoch.minTip ([#316](https://github.com/taikoxyz/simple-taiko-node/issues/316)) ([e8c1f9a](https://github.com/taikoxyz/simple-taiko-node/commit/e8c1f9a836865336149839b31e4f4529d13290c9))
* **repo:** add editorconfig ([#320](https://github.com/taikoxyz/simple-taiko-node/issues/320)) ([bc5a9d0](https://github.com/taikoxyz/simple-taiko-node/commit/bc5a9d00d6aad03d2abc21de084fdf442781edab))


### Bug Fixes

* double quotation ([#312](https://github.com/taikoxyz/simple-taiko-node/issues/312)) ([8d5be17](https://github.com/taikoxyz/simple-taiko-node/commit/8d5be172de0b49f75cf15b7e36a2c6f3ae7f9536))


### Chores

* **docker:** update geth image ([#321](https://github.com/taikoxyz/simple-taiko-node/issues/321)) ([246dbb3](https://github.com/taikoxyz/simple-taiko-node/commit/246dbb3fd93e35a76d19eb985a6225b2448ce1a1))


### Workflow

* **repo:** improving repo workflows/renaming ([#317](https://github.com/taikoxyz/simple-taiko-node/issues/317)) ([589456b](https://github.com/taikoxyz/simple-taiko-node/commit/589456b372378558804ed1ddd68ec0a9ab0c085d))

## [1.3.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.2.0...v1.3.0) (2024-07-08)


### Features

* **proposer:** remove unused `BLOCK_BUILDER_TIP` ([#309](https://github.com/taikoxyz/simple-taiko-node/issues/309)) ([f11e6be](https://github.com/taikoxyz/simple-taiko-node/commit/f11e6be27c8da1662154a0b06430a86f11ab6f1f))
* **proposer:** rm tier fee ([#310](https://github.com/taikoxyz/simple-taiko-node/issues/310)) ([aaf2ce0](https://github.com/taikoxyz/simple-taiko-node/commit/aaf2ce0665f3de8d69947d44ef8c7fa1521ee9b0))
* remove unused configs ([#305](https://github.com/taikoxyz/simple-taiko-node/issues/305)) ([073bf24](https://github.com/taikoxyz/simple-taiko-node/commit/073bf24be6557fcc80968b3ff24bd94de17f91c7))

## [1.2.0](https://github.com/taikoxyz/simple-taiko-node/compare/v1.1.0...v1.2.0) (2024-07-01)


### Features

* apply assignmenthook update for hekla  ([#301](https://github.com/taikoxyz/simple-taiko-node/issues/301)) ([db01c11](https://github.com/taikoxyz/simple-taiko-node/commit/db01c113d8952c888d8031afc50d8d9bf2969493))
* **mainnet:** bump client version ([#304](https://github.com/taikoxyz/simple-taiko-node/issues/304)) ([67bcff0](https://github.com/taikoxyz/simple-taiko-node/commit/67bcff0fb5abb3a00ac6abea07b2d18e8874c618))

## 1.0.0 (2024-05-30)


### Features

* add echo informing of the proposer being disabled before 'sleep infinity' ([#139](https://github.com/taikoxyz/simple-taiko-node/issues/139)) ([541c04b](https://github.com/taikoxyz/simple-taiko-node/commit/541c04b8348e2ad39b87dba3546aeebd9d604529))
* add update-env.sh util script ([#106](https://github.com/taikoxyz/simple-taiko-node/issues/106)) ([0a15475](https://github.com/taikoxyz/simple-taiko-node/commit/0a15475e43c6d68bf053cce1f0ed277cd9149ea8))
* **all:** add default `proposeBlockTxGasTipCap` flag value for proposers ([#110](https://github.com/taikoxyz/simple-taiko-node/issues/110)) ([6b084e2](https://github.com/taikoxyz/simple-taiko-node/commit/6b084e26be97b9c3566d94ed0eceaf33e88103e4))
* **all:** initial commit ([#1](https://github.com/taikoxyz/simple-taiko-node/issues/1)) ([c44176c](https://github.com/taikoxyz/simple-taiko-node/commit/c44176c6c5c017ceb5d945d3a8d348ee2b67d30a))
* **all:** update configurations for alpha-5 testnet ([#121](https://github.com/taikoxyz/simple-taiko-node/issues/121)) ([3f5347e](https://github.com/taikoxyz/simple-taiko-node/commit/3f5347e9a308ee37a3c7861d02b5705e7c4b66a7))
* **alpha-3:** add more bootnodes ([#58](https://github.com/taikoxyz/simple-taiko-node/issues/58)) ([76de101](https://github.com/taikoxyz/simple-taiko-node/commit/76de101a175c9185421da22579f90dabb9ea1f38))
* **alpha-4:** add Eldfell network configs ([#67](https://github.com/taikoxyz/simple-taiko-node/issues/67)) ([d34b96b](https://github.com/taikoxyz/simple-taiko-node/commit/d34b96b062d19a0562398202aca2b597e81f6a5b))
* **alpha-6:** add `Katla` network configs ([#158](https://github.com/taikoxyz/simple-taiko-node/issues/158)) ([bf1d2a2](https://github.com/taikoxyz/simple-taiko-node/commit/bf1d2a2b59bcdb6f702d3cb56ac6781ed134ea88))
* **chore:** update docker-compose configurations ([#53](https://github.com/taikoxyz/simple-taiko-node/issues/53)) ([3ee89e7](https://github.com/taikoxyz/simple-taiko-node/commit/3ee89e7bd47dfc0c640298641e434f253169eec9))
* docker-compose.yml formatting ([#225](https://github.com/taikoxyz/simple-taiko-node/issues/225)) ([0ca3155](https://github.com/taikoxyz/simple-taiko-node/commit/0ca3155fc29840857204e6c0a32e73eb6eafb78f))
* **eldfell:** add `PROVE_UNASSIGNED_BLOCKS` env ([#69](https://github.com/taikoxyz/simple-taiko-node/issues/69)) ([1d6e1cd](https://github.com/taikoxyz/simple-taiko-node/commit/1d6e1cd5be8fe55568ff349cf0ca3ef16440f835))
* **eldfell:** increase zkevm-chain-rpcd wait timeout ([#73](https://github.com/taikoxyz/simple-taiko-node/issues/73)) ([d9e6586](https://github.com/taikoxyz/simple-taiko-node/commit/d9e6586bbb941095e60ac6e506622d9a7139df2a))
* **eldfell:** update `PORT_L3_EXECTION_ENGINE_HTTP` && `PORT_L3_EXECTION_ENGINE_WS` ([#68](https://github.com/taikoxyz/simple-taiko-node/issues/68)) ([3a75489](https://github.com/taikoxyz/simple-taiko-node/commit/3a75489a28b3c3cde17462f0bd4fdef04a680c01))
* **eldfell:** update default bootnodes ([#98](https://github.com/taikoxyz/simple-taiko-node/issues/98)) ([2b8d662](https://github.com/taikoxyz/simple-taiko-node/commit/2b8d6620dc2e8ae146cc9812ca02fc9bfe96ad24))
* **eldfell:** update service names ([#70](https://github.com/taikoxyz/simple-taiko-node/issues/70)) ([e7cb642](https://github.com/taikoxyz/simple-taiko-node/commit/e7cb6425bbf7d1c5972888c33f1bd70d573c1c96))
* **env:** use golden touch account as `L2_THROWAWAY_BLOCK_BUILDER` ([#12](https://github.com/taikoxyz/simple-taiko-node/issues/12)) ([fc4de37](https://github.com/taikoxyz/simple-taiko-node/commit/fc4de37d2b16a9c3b2c2c963bf4809395cc7482f))
* **grimsvotn:** add `DISABLE_P2P_SYNC` option ([#57](https://github.com/taikoxyz/simple-taiko-node/issues/57)) ([55cc163](https://github.com/taikoxyz/simple-taiko-node/commit/55cc16384591b5b84f14f0ce3ea55a7a36125ebe))
* **grimsvotn:** update A3 zkevm-chain-prover-rpcd memory limit ([#95](https://github.com/taikoxyz/simple-taiko-node/issues/95)) ([836d217](https://github.com/taikoxyz/simple-taiko-node/commit/836d217185be902d769cff2f7a2b0ca536d75e44))
* **grímsvötn:** update p2p sync timeout config ([#56](https://github.com/taikoxyz/simple-taiko-node/issues/56)) ([c1b5cd0](https://github.com/taikoxyz/simple-taiko-node/commit/c1b5cd02bff6f8502b0a842ab2b89f72babfcbec))
* handle unix signals ([#224](https://github.com/taikoxyz/simple-taiko-node/issues/224)) ([247ef63](https://github.com/taikoxyz/simple-taiko-node/commit/247ef6382e17f9f1aa381440348dc4d13e3c2558))
* **hekla:** introduce `--gpo.ignoreprice` flag ([#247](https://github.com/taikoxyz/simple-taiko-node/issues/247)) ([e5221f2](https://github.com/taikoxyz/simple-taiko-node/commit/e5221f24a418cb6fa49b95a41c15edcedefa0779))
* **hekla:** modify `simple-taiko-node` for hekla  ([#205](https://github.com/taikoxyz/simple-taiko-node/issues/205)) ([b0a1b21](https://github.com/taikoxyz/simple-taiko-node/commit/b0a1b211a8d1e6610ea3ad8c31594faba4adc37d))
* **hekla:** update default `TX_GAS_LIMIT` config ([#209](https://github.com/taikoxyz/simple-taiko-node/issues/209)) ([e75f5f0](https://github.com/taikoxyz/simple-taiko-node/commit/e75f5f05027c59e17d0b31122119ede035f6f2b6))
* **jolnir:** update default gas limit configurations ([#129](https://github.com/taikoxyz/simple-taiko-node/issues/129)) ([96c48a5](https://github.com/taikoxyz/simple-taiko-node/commit/96c48a5b2c3a5b8f42e5a29305482de46644305b))
* **katla:** improve `start-zkevm-chain-rpcd.sh` ([#164](https://github.com/taikoxyz/simple-taiko-node/issues/164)) ([e56a6e7](https://github.com/taikoxyz/simple-taiko-node/commit/e56a6e754774f703817ea5213968c4c6f576bcd0))
* **log:** add `PROVER IS DISABLED` log ([#178](https://github.com/taikoxyz/simple-taiko-node/issues/178)) ([25af49c](https://github.com/taikoxyz/simple-taiko-node/commit/25af49c14687cc8345394f690f5c94ce8aa4c6ae))
* **mainnet:** update mainnet configs ([#276](https://github.com/taikoxyz/simple-taiko-node/issues/276)) ([ebe5bd7](https://github.com/taikoxyz/simple-taiko-node/commit/ebe5bd726915c3ff17c0f9c8b7f6c5f70e826515))
* **node:** set locals in node ([#92](https://github.com/taikoxyz/simple-taiko-node/issues/92)) ([08a5b0d](https://github.com/taikoxyz/simple-taiko-node/commit/08a5b0d132bd16646dc8c10ee575ed0978f45a4c))
* **proposer:** proposer can only propose local transactions ([#91](https://github.com/taikoxyz/simple-taiko-node/issues/91)) ([8ba42aa](https://github.com/taikoxyz/simple-taiko-node/commit/8ba42aa089d356ea61f882f9dfc2a0091bde2476))
* **proposer:** Proposer gas limit + script refactor ([#101](https://github.com/taikoxyz/simple-taiko-node/issues/101)) ([17f1d0c](https://github.com/taikoxyz/simple-taiko-node/commit/17f1d0c495e146b8668c77e6c225605f586da4c3))
* **proposer:** update proposer RPC config temporarily ([#26](https://github.com/taikoxyz/simple-taiko-node/issues/26)) ([23eb266](https://github.com/taikoxyz/simple-taiko-node/commit/23eb266addf42fdd9e80ca2c7d66e400fc38c5dd))
* **proposer:** wait receipt timeout flags + refactor prover scripts ([#104](https://github.com/taikoxyz/simple-taiko-node/issues/104)) ([e76acb9](https://github.com/taikoxyz/simple-taiko-node/commit/e76acb94f888863d825b2c3f6c5be1c393552cac))
* **prover:** add proof skip size config for L3 ([#118](https://github.com/taikoxyz/simple-taiko-node/issues/118)) ([569592a](https://github.com/taikoxyz/simple-taiko-node/commit/569592a0c3d404a3fbfba99668b2cddd3b379429))
* **prover:** add prove block tx gas limit flag  ([#115](https://github.com/taikoxyz/simple-taiko-node/issues/115)) ([42d62bc](https://github.com/taikoxyz/simple-taiko-node/commit/42d62bc24b074b5c3ccdc79b227963d4fbaee1d3))
* **prover:** support running node and sgx prover on different servers ([#221](https://github.com/taikoxyz/simple-taiko-node/issues/221)) ([e84507a](https://github.com/taikoxyz/simple-taiko-node/commit/e84507acf1a280b2838f66b00e1948eba88c0f0e))
* **repo:** enable OpenAI-based review ([#52](https://github.com/taikoxyz/simple-taiko-node/issues/52)) ([6d0d863](https://github.com/taikoxyz/simple-taiko-node/commit/6d0d863b1341ee158da946ffa2c78d08afcc65c6))
* rm useless config ([#281](https://github.com/taikoxyz/simple-taiko-node/issues/281)) ([eebfffa](https://github.com/taikoxyz/simple-taiko-node/commit/eebfffa82ff7c1a5eeddbd549cc7371914ed323a))
* **script:** add condition to check requirement variables for proposer/prover ([#238](https://github.com/taikoxyz/simple-taiko-node/issues/238)) ([fca0c9a](https://github.com/taikoxyz/simple-taiko-node/commit/fca0c9ae061085f4d11b1abf9452b71f9ed58cbd))
* set default home dashboard ([#174](https://github.com/taikoxyz/simple-taiko-node/issues/174)) ([63a9aa7](https://github.com/taikoxyz/simple-taiko-node/commit/63a9aa7010b81da18e2a68dda767bf66e2020f05))
* start multiple `zkevm-chain` provers ([#94](https://github.com/taikoxyz/simple-taiko-node/issues/94)) ([2d12441](https://github.com/taikoxyz/simple-taiko-node/commit/2d12441c0743192701443c86bd337f463d609376))
* update default ports ([#89](https://github.com/taikoxyz/simple-taiko-node/issues/89)) ([27b902e](https://github.com/taikoxyz/simple-taiko-node/commit/27b902eee8dab2d1c3dea3a6fbb32b1907f6ab5f))
* update sync timeout ([#59](https://github.com/taikoxyz/simple-taiko-node/issues/59)) ([cfbc2a0](https://github.com/taikoxyz/simple-taiko-node/commit/cfbc2a02b95304382c424dd2c752646799647bc8))


### Bug Fixes

* add backwards compat for new env var and small typo ([#96](https://github.com/taikoxyz/simple-taiko-node/issues/96)) ([f7610ad](https://github.com/taikoxyz/simple-taiko-node/commit/f7610ad4902c2d23df45deab8678fe8d66d1b71e))
* add default value for `GETH_ADDITIONAL_ARGS` ([#267](https://github.com/taikoxyz/simple-taiko-node/issues/267)) ([aec2678](https://github.com/taikoxyz/simple-taiko-node/commit/aec2678258dcd6d1272e6bbd9f023129f06931c9))
* **docker-compose:** make hard-coded prover's port dynamic ([#41](https://github.com/taikoxyz/simple-taiko-node/issues/41)) ([8c08689](https://github.com/taikoxyz/simple-taiko-node/commit/8c0868924adbb558fb2d6f2178923d95428b51d3))
* **docs:** correct IP format in `.env.sample` endpoints ([#170](https://github.com/taikoxyz/simple-taiko-node/issues/170)) ([3bf68cd](https://github.com/taikoxyz/simple-taiko-node/commit/3bf68cda84997082fb3ecdcc48d0aa668e4f9996))
* **eldfell:** fix `--proveUnassignedBlocks` flag setting ([#109](https://github.com/taikoxyz/simple-taiko-node/issues/109)) ([0a86e18](https://github.com/taikoxyz/simple-taiko-node/commit/0a86e18dfa0a038f8d36c8793870326e8fd4e96e))
* **eldfell:** fix zkevm-chain-proverd port in prover relayer script ([#72](https://github.com/taikoxyz/simple-taiko-node/issues/72)) ([dee982e](https://github.com/taikoxyz/simple-taiko-node/commit/dee982e27ee8a14dac09bb6b084fef804a8cd9d4))
* **eldfell:** make zkevm-rpcd-chain port number explicit ([#71](https://github.com/taikoxyz/simple-taiko-node/issues/71)) ([38d2114](https://github.com/taikoxyz/simple-taiko-node/commit/38d2114ca1e68a70e574f129c7fa3e02677d3904))
* **eldfell:** update zkevm-chain-rpcd host ([#75](https://github.com/taikoxyz/simple-taiko-node/issues/75)) ([5a63f47](https://github.com/taikoxyz/simple-taiko-node/commit/5a63f47ca5fce97fc32cfc05fbbb4ac8d3e39beb))
* **eldfell:** Use correct env flag in start-prover-relayer.sh ([#79](https://github.com/taikoxyz/simple-taiko-node/issues/79)) ([9c1cdba](https://github.com/taikoxyz/simple-taiko-node/commit/9c1cdba5d730ae3cc5ba50656d797e3db18d28b1))
* **eldfell:** Use env variable for port assignment in start-zkevm-chain-rpcd.sh ([#77](https://github.com/taikoxyz/simple-taiko-node/issues/77)) ([a1dfb6d](https://github.com/taikoxyz/simple-taiko-node/commit/a1dfb6d26fa35e43a9e81dca1f720d67224272a0))
* **env:** fix sample env file formatting ([7c15a6d](https://github.com/taikoxyz/simple-taiko-node/commit/7c15a6d790abd09471cc4aeb23bcc1144525b93e))
* **env:** Update for .env.sample.l3 ([#99](https://github.com/taikoxyz/simple-taiko-node/issues/99)) ([4b6ab2a](https://github.com/taikoxyz/simple-taiko-node/commit/4b6ab2af4020bbde30b0c863706e1c6e82c97b2d))
* **env:** update sample env files ([#90](https://github.com/taikoxyz/simple-taiko-node/issues/90)) ([a62598d](https://github.com/taikoxyz/simple-taiko-node/commit/a62598d7fb026fbf0fc9d07ba408ff98cde8942c))
* **grafana:** set `'Instant'` as default query type for instant metrics ([#251](https://github.com/taikoxyz/simple-taiko-node/issues/251)) ([9201f1a](https://github.com/taikoxyz/simple-taiko-node/commit/9201f1aabf73b6ee97cb093d3517cb634df43ee6))
* **grimsvotn:** fix `start-prover-relayer.sh` script ([#108](https://github.com/taikoxyz/simple-taiko-node/issues/108)) ([f83afaa](https://github.com/taikoxyz/simple-taiko-node/commit/f83afaa6936981e94cda328336db5a92641157f7))
* l3 grafana dashboard ([#88](https://github.com/taikoxyz/simple-taiko-node/issues/88)) ([8f4e9ba](https://github.com/taikoxyz/simple-taiko-node/commit/8f4e9bab90de80bdc886c2e32ef4b13ccc6d8333))
* **node:** Typo fix spelling EXECUTION .env and yml files ([#119](https://github.com/taikoxyz/simple-taiko-node/issues/119)) ([d5f46aa](https://github.com/taikoxyz/simple-taiko-node/commit/d5f46aab36f90d352b48929eeb91d19270525da3))
* **proposer:** check enabled before args ([#255](https://github.com/taikoxyz/simple-taiko-node/issues/255)) ([d54b0dd](https://github.com/taikoxyz/simple-taiko-node/commit/d54b0dd0205a2709b0505cf5cc791889a2cdbe7e))
* **proposer:** fix proposer var ([#256](https://github.com/taikoxyz/simple-taiko-node/issues/256)) ([d9afb56](https://github.com/taikoxyz/simple-taiko-node/commit/d9afb56f9beb7b8dc26d7f13c4d8795bede8f771))
* **prover:** reorder script args ([#204](https://github.com/taikoxyz/simple-taiko-node/issues/204)) ([df19538](https://github.com/taikoxyz/simple-taiko-node/commit/df19538417978c8f822fe1b71b46cbbd8a041ecf))
* **repo:** fix openAI review workflow ([#54](https://github.com/taikoxyz/simple-taiko-node/issues/54)) ([d8896cf](https://github.com/taikoxyz/simple-taiko-node/commit/d8896cf2c0e94fb1c0da36a1cb9b2df658f5c17e))
* **script:** use docker internal port ([#45](https://github.com/taikoxyz/simple-taiko-node/issues/45)) ([1ef326a](https://github.com/taikoxyz/simple-taiko-node/commit/1ef326a8afbdceee159f051b6c35d3277750cab0))
* update docker-compose.yml for better p2p configuration ([#258](https://github.com/taikoxyz/simple-taiko-node/issues/258)) ([bce9544](https://github.com/taikoxyz/simple-taiko-node/commit/bce95442c8e2840ece0daca4138eea26e8e50e22))
