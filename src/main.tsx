import { Component, StrictMode, type ErrorInfo, type ReactNode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

class ErrorBoundary extends Component<{children: ReactNode}, {failed: boolean}> {
  state = { failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Application render failed', error, info)
  }

  render() {
    if (this.state.failed) {
      return (
        <main style={{minHeight:'100vh',display:'grid',placeItems:'center',padding:'24px',fontFamily:'sans-serif'}}>
          <section style={{maxWidth:'520px',textAlign:'center'}}>
            <h1>We could not open Grupee</h1>
            <p>Please refresh the page. If the problem continues, contact support and include the current time.</p>
            <button type="button" onClick={() => location.reload()} style={{border:0,borderRadius:'8px',background:'#1e3a8a',color:'#fff',padding:'12px 18px',cursor:'pointer'}}>Refresh</button>
          </section>
        </main>
      )
    }
    return this.props.children
  }
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>,
)
