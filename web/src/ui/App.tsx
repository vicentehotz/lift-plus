import { useEffect, useState } from "react";
import { APP_VERSION } from "../domain/version";

/**
 * Shell da P0: tela inicial que confirma que o PWA carrega, funciona offline e
 * pode ser instalado. As telas de produto (fichas, execução, histórico) chegam
 * nas fases seguintes.
 */
export function App() {
  const [standalone, setStandalone] = useState(false);

  useEffect(() => {
    const mm = window.matchMedia("(display-mode: standalone)");
    const isStandalone =
      mm.matches ||
      // iOS Safari expõe navigator.standalone quando instalado na tela de início.
      (window.navigator as { standalone?: boolean }).standalone === true;
    setStandalone(isStandalone);
  }, []);

  return (
    <main className="shell">
      <h1 className="logo">
        Lift<span aria-hidden="true">+</span>
      </h1>
      <p className="tagline">Controle de treino, offline-first.</p>

      <section className="card" aria-label="Estado do app">
        <Row label="Versão" value={APP_VERSION} />
        <Row label="Modo" value={standalone ? "Instalado" : "Navegador"} />
        <Row label="Offline" value="pronto (app shell em cache)" />
      </section>

      {!standalone && (
        <p className="hint">
          Para instalar no iPhone: no Safari, toque em <strong>Compartilhar</strong>{" "}
          e depois em <strong>Adicionar à Tela de Início</strong>.
        </p>
      )}
    </main>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="row">
      <span className="row-label">{label}</span>
      <span className="row-value">{value}</span>
    </div>
  );
}
