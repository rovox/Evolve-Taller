import { createConfig, http } from 'wagmi'
//import { mainnet, sepolia } from 'wagmi/chains'
import { injected, metaMask } from 'wagmi/connectors'

export const evolveLocalnet = {
  id: 31337,
  name: 'Evolve Local',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
  },
} as const

export const config = createConfig({
  chains: [evolveLocalnet],
  connectors: [
    injected(),
    metaMask(),
  ],
  transports: {
    [evolveLocalnet.id]: http(),
    //[sepolia.id]: http(),
  },
})