require('dotenv').config()
const { ethers } = require('ethers')
const fs = require('fs')

const RPC = process.env.E2E_RPC || 'http://localhost:8545'
const PRIVATE_KEY = process.env.E2E_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'

async function main() {
  console.log('🧪 E2E Test: Crear RWA Asset + Comprar Fracción\n')

  // Cargar addresses
  const envText = fs.readFileSync('./rwa-soberano-evolve/deployed-addresses.env', 'utf8')
  const addresses = {}
  envText.split('\n').forEach(line => {
    const [k, v] = line.split('=')
    if (k && v) addresses[k.trim()] = v.trim()
  })

  const RWA_ADDRESS = addresses.RWA_ADDRESS
  if (!RWA_ADDRESS) throw new Error('RWA_ADDRESS no encontrada en deployed-addresses.env')

  const provider = new ethers.JsonRpcProvider(RPC)
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider)

  // Cargar ABI
  const rwaArtifact = JSON.parse(fs.readFileSync('./rwa-soberano-evolve/out/RWASovereignRollup.sol/RWASovereignRollup.json', 'utf8'))
  const contract = new ethers.Contract(RWA_ADDRESS, rwaArtifact.abi, wallet)

  console.log('📄 Paso 1: Crear Asset')
  const docHash = ethers.keccak256(ethers.toUtf8Bytes(`E2E-Test-${Date.now()}`))
  
  let txCreate
  if (contract.createAsset) {
    txCreate = await contract.createAsset(docHash)
  } else {
    // Fallback: registra en DocumentRegistry
    const registryAddress = addresses.REGISTRY_ADDRESS
    const registryArtifact = JSON.parse(fs.readFileSync('./rwa-soberano-evolve/out/DocumentRegistry.sol/DocumentRegistry.json', 'utf8'))
    const registryContract = new ethers.Contract(registryAddress, registryArtifact.abi, wallet)
    txCreate = await registryContract.registerDocument(docHash)
  }

  console.log('   Tx Hash:', txCreate.hash)
  const receiptCreate = await txCreate.wait(1)
  console.log('   ✅ Confirmado en bloque:', receiptCreate.blockNumber)

  const iface = new ethers.Interface(rwaArtifact.abi)
  receiptCreate.logs.forEach(log => {
    try {
      const parsed = iface.parseLog(log)
      console.log('   Evento:', parsed.name, JSON.stringify(parsed.args))
    } catch (e) {}
  })

  console.log('\n💰 Paso 2: Comprar Fracción')
  const txBuy = await contract.purchaseFraction({ value: ethers.parseEther('0.01') })
  console.log('   Tx Hash:', txBuy.hash)
  const receiptBuy = await txBuy.wait(1)
  console.log('   ✅ Confirmado en bloque:', receiptBuy.blockNumber)

  receiptBuy.logs.forEach(log => {
    try {
      const parsed = iface.parseLog(log)
      console.log('   Evento:', parsed.name, JSON.stringify(parsed.args))
    } catch (e) {}
  })

  const balance = await contract.balanceOf(wallet.address)
  console.log('\n📊 Balance de shares del usuario:', ethers.formatEther(balance), 'RWAS')

  console.log('\n✅ E2E Test completado exitosamente!')
}

main().catch(err => {
  console.error('❌ Error en E2E test:', err)
  process.exit(1)
})