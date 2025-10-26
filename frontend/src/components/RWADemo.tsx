import React, { useState, useEffect } from 'react'
import { BrowserProvider, Contract, Interface, keccak256, parseEther, toUtf8Bytes, type ContractTransactionResponse, type Signer } from 'ethers'
import { Activity, FileText, ShoppingCart, Loader2, Check, ExternalLink } from 'lucide-react'

// Importa ABIs (asume que update-abis.sh ya corrió)
import rwaAbi from '../abis/RWASovereignRollup.json'
import registryAbi from '../abis/DocumentRegistry.json'
import tokenAbi from '../abis/AssetToken.json'

interface TxResult {
  hash: string
  blockNumber?: number
  events?: any[]
  contractInfo?: any
}

export default function RWADemo() {
  const [provider, setProvider] = useState<BrowserProvider | null>(null)
  const [signer, setSigner] = useState<Signer | null>(null)
  const [account, setAccount] = useState<string>('')
  const [status, setStatus] = useState<string>('Desconectado')
  const [loading, setLoading] = useState(false)

  // Resultados de transacciones
  const [createTxResult, setCreateTxResult] = useState<TxResult | null>(null)
  const [purchaseTxResult, setPurchaseTxResult] = useState<TxResult | null>(null)

  // Direcciones (desde deployed-addresses.env vía backend o import.meta.env)
  const RPC_URL = import.meta.env.VITE_RPC_URL || 'http://localhost:8545'
  const REGISTRY_ADDRESS = import.meta.env.VITE_REGISTRY_ADDRESS || ''
  const RWA_ADDRESS = import.meta.env.VITE_RWA_ADDRESS || ''

  useEffect(() => {
    loadAddressesFromBackend()
  }, [])

  async function loadAddressesFromBackend() {
    try {
      const res = await fetch('/deployed-addresses.env')
      const text = await res.text()
      const lines = text.split('\n')
      lines.forEach(line => {
        const [key, val] = line.split('=')
        if (key && val) {
          ;(window as any)[`__${key}`] = val.trim()
        }
      })
    } catch (e) {
      console.warn('No se pudo cargar deployed-addresses.env desde backend')
    }
  }

  async function connectWallet() {
    setLoading(true)
    try {
      const anyWin = window as any
      if (!anyWin.ethereum) {
        alert('MetaMask no detectado. Instala MetaMask.')
        return
      }
      const web3Provider = new BrowserProvider(anyWin.ethereum)
      await web3Provider.send('eth_requestAccounts', [])
      const signer = await web3Provider.getSigner()
      const address = await signer.getAddress()

      setProvider(web3Provider)
      setSigner(signer)
      setAccount(address)
      setStatus(`Conectado: ${address.slice(0, 6)}...${address.slice(-4)}`)
    } catch (e: any) {
      setStatus('Error al conectar: ' + e.message)
    } finally {
      setLoading(false)
    }
  }

  async function createRWAAsset() {
    if (!signer) {
      alert('Primero conecta tu wallet')
      return
    }
    setLoading(true)
    setStatus('Creando RWA asset...')
    try {
      const rwaAddress = (window as any).__RWA_ADDRESS || RWA_ADDRESS
      if (!rwaAddress) throw new Error('RWA_ADDRESS no configurada')

      const contract = new Contract(rwaAddress, rwaAbi.abi, signer)
      const documentHash = keccak256(toUtf8Bytes(`RWA-${Date.now()}`))

      let tx: ContractTransactionResponse
      if (contract.createAsset) {
        tx = await contract.createAsset(documentHash)
      } else {
        const regAddress = (window as any).__REGISTRY_ADDRESS || REGISTRY_ADDRESS
        const regContract = new Contract(regAddress, registryAbi.abi, signer)
        tx = await regContract.registerDocument(documentHash)
      }

      setStatus(`Tx enviada: ${tx.hash}. Esperando confirmación...`)
      const receipt = await tx.wait(1)

      const iface = new Interface(rwaAbi.abi)
      const parsedEvents = receipt.logs
        .map((log: any) => {
          try {
            return iface.parseLog(log)
          } catch {
            return null
          }
        })
        .filter(Boolean)

      // Leer info del contrato
      const totalAssets = await contract.totalAssets?.() || 'N/A'
      const blockNumber = receipt.blockNumber

      setCreateTxResult({
        hash: receipt?.hash ?? tx?.hash ?? '',
        blockNumber,
        events: parsedEvents,
        contractInfo: { totalAssets: totalAssets.toString(), documentHash }
      })
      setStatus(`✅ Asset creado en bloque ${blockNumber}`)
    } catch (e: any) {
      setStatus('Error: ' + (e?.message || e))
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  async function purchaseFraction() {
    if (!signer) {
      alert('Primero conecta tu wallet')
      return
    }
    setLoading(true)
    setStatus('Comprando fracción de RWA...')
    try {
      const rwaAddress = (window as any).__RWA_ADDRESS || RWA_ADDRESS
      if (!rwaAddress) throw new Error('RWA_ADDRESS no configurada')

      const contract = new Contract(rwaAddress, rwaAbi.abi, signer)
      const amountWei = parseEther('0.01')

      const tx = await contract.purchaseFraction({ value: amountWei })
      setStatus(`Tx enviada: ${tx.hash}. Esperando confirmación...`)
      const receipt = await tx.wait(1)

      const iface = new Interface(rwaAbi.abi)
      const parsedEvents = receipt.logs
        .map((log: any) => {
          try {
            return iface.parseLog(log)
          } catch {
            return null
          }
        })
        .filter(Boolean)

      const balance = await contract.balanceOf?.(account) || 'N/A'
      const blockNumber = receipt.blockNumber

      setPurchaseTxResult({
        hash: receipt?.hash ?? tx?.hash ?? '',
        blockNumber,
        events: parsedEvents,
        contractInfo: { userBalance: balance.toString(), amountPaid: amountWei.toString() }
      })
      setStatus(`✅ Fracción comprada en bloque ${blockNumber}`)
    } catch (e: any) {
      setStatus('Error: ' + (e?.message || e))
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ padding: '24px', maxWidth: '900px', margin: '0 auto' }}>
      <h2 style={{ marginBottom: '16px', fontSize: '24px', fontWeight: 'bold' }}>
        🏦 Demo RWA - Crear Token y Comprar Fracción
      </h2>

      {/* Wallet Status */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.1), rgba(168, 85, 247, 0.1))',
        padding: '16px',
        borderRadius: '12px',
        marginBottom: '24px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <Activity size={20} color={account ? '#10b981' : '#6b7280'} />
          <span style={{ fontWeight: '600' }}>{status}</span>
        </div>
        {!account && (
          <button
            onClick={connectWallet}
            disabled={loading}
            style={{
              marginTop: '12px',
              padding: '8px 16px',
              background: '#6366f1',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              cursor: loading ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            {loading ? <Loader2 className="animate-spin" size={16} /> : null}
            Conectar Wallet
          </button>
        )}
      </div>

      {/* Actions */}
      {account && (
        <div style={{ display: 'grid', gap: '16px', gridTemplateColumns: '1fr 1fr' }}>
          <button
            onClick={createRWAAsset}
            disabled={loading}
            style={{
              padding: '16px',
              background: 'linear-gradient(135deg, #10b981, #059669)',
              color: '#fff',
              border: 'none',
              borderRadius: '12px',
              cursor: loading ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              fontSize: '16px',
              fontWeight: '600'
            }}
          >
            <FileText size={20} />
            Crear RWA Asset
          </button>

          <button
            onClick={purchaseFraction}
            disabled={loading || !createTxResult}
            style={{
              padding: '16px',
              background: createTxResult ? 'linear-gradient(135deg, #f59e0b, #d97706)' : '#9ca3af',
              color: '#fff',
              border: 'none',
              borderRadius: '12px',
              cursor: loading || !createTxResult ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              fontSize: '16px',
              fontWeight: '600'
            }}
          >
            <ShoppingCart size={20} />
            Comprar Fracción (0.01 ETH)
          </button>
        </div>
      )}

      {/* Results */}
      {createTxResult && (
        <ResultCard title="✅ Asset Creado" result={createTxResult} />
      )}

      {purchaseTxResult && (
        <ResultCard title="✅ Fracción Comprada" result={purchaseTxResult} />
      )}
    </div>
  )
}

function ResultCard({ title, result }: { title: string; result: TxResult }) {
  return (
    <div style={{
      marginTop: '24px',
      background: 'rgba(16, 185, 129, 0.1)',
      border: '1px solid rgba(16, 185, 129, 0.3)',
      borderRadius: '12px',
      padding: '16px'
    }}>
      <h3 style={{ fontSize: '18px', fontWeight: '700', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
        <Check size={20} color="#10b981" />
        {title}
      </h3>

      <div style={{ fontSize: '14px', fontFamily: 'monospace', color: '#d1d5db' }}>
        <div style={{ marginBottom: '8px' }}>
          <strong>Tx Hash:</strong>{' '}
          <a href={`http://localhost/tx/${result.hash}`} target="_blank" rel="noopener" style={{ color: '#60a5fa', textDecoration: 'underline' }}>
            {result.hash.slice(0, 10)}...{result.hash.slice(-8)}
            <ExternalLink size={12} style={{ display: 'inline', marginLeft: '4px' }} />
          </a>
        </div>
        {result.blockNumber && <div><strong>Bloque:</strong> {result.blockNumber}</div>}
        {result.contractInfo && (
          <div style={{ marginTop: '8px' }}>
            <strong>Datos del Contrato:</strong>
            <pre style={{ background: '#1f2937', padding: '8px', borderRadius: '6px', marginTop: '4px', overflow: 'auto' }}>
              {JSON.stringify(result.contractInfo, null, 2)}
            </pre>
          </div>
        )}
        {result.events && result.events.length > 0 && (
          <div style={{ marginTop: '8px' }}>
            <strong>Eventos Emitidos:</strong>
            <pre style={{ background: '#1f2937', padding: '8px', borderRadius: '6px', marginTop: '4px', overflow: 'auto' }}>
              {JSON.stringify(result.events.map(e => ({ name: e.name, args: e.args })), null, 2)}
            </pre>
          </div>
        )}
      </div>
    </div>
  )
}