import { useEffect, useMemo, useState } from "react";
import "./QuizCRUD.css";

// As constantes e a função utilitária ficam no escopo global do módulo.
const REST_PREFIX = "/rest";
const GRPC_PREFIX = "/grpc";

function prefixFor(mode) {
  return mode === "rest" ? REST_PREFIX : GRPC_PREFIX;
}

async function jsonFetch(url, { method = "GET", body, token } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const texto = await res.text();
  
  let data = null;
  try { data = texto ? JSON.parse(texto) : null; } catch { data = { raw: texto }; }
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${texto}`);
  return data;
}

const DEMO_DATA = [
  {
    id: 1,
    texto: "O que é gRPC?",
    alternativas: ["Protocolo de roteamento", "Framework RPC", "Banco de dados", "Balanceador"],
    indice_resposta: 1,
    explicacao: "gRPC é um framework RPC de alto desempenho baseado em HTTP/2 e Protobuf.",
  },
  {
    id: 2,
    texto: "Qual protocolo de transporte o gRPC usa por padrão?",
    alternativas: ["HTTP/1.1", "WebSocket", "HTTP/2", "FTP"],
    indice_resposta: 2,
    explicacao: "gRPC usa HTTP/2 por padrão.",
  },
];

// O componente ModeToggle foi simplificado para ter apenas sua responsabilidade.
/*function ModeToggle({ mode, setMode }) {
  return (
    <div className="crud-toggle">
      <button
        type="button"
        className={mode === "rest" ? "crud-btn active" : "crud-btn"}
        onClick={() => setMode("rest")}
      >
        REST
      </button>
      <button
        type="button"
        className={mode === "grpc" ? "crud-btn active" : "crud-btn"}
        onClick={() => setMode("grpc")}
      >
        gRPC
      </button>
    </div>
  );
}*/

function QuestionForm({ value, onChange, onSubmit, onCancel, submitting, mode }) {
  const v = value;
  function set(field, val) { onChange({ ...v, [field]: val }); }
  function setOption(idx, val) {
    const opts = [...v.alternativas];
    opts[idx] = val;
    onChange({ ...v, alternativas: opts });
  }
  return (
    <form className="crud-form" onSubmit={onSubmit}>
      <label className="crud-label">Texto da questão</label>
      <textarea
        className="crud-input"
        rows={3}
        value={v.texto}
        onChange={(e) => set("texto", e.target.value)}
        placeholder="Digite o enunciado da questão"
        required
      />

      {["A", "B", "C", "D"].map((letra, i) => (
        <div key={i}>
          <label className="crud-label">Alternativa {letra}</label>
          <input
            className="crud-input"
            value={v.alternativas[i]}
            onChange={(e) => setOption(i, e.target.value)}
            required
          />
        </div>
      ))}

      <label className="crud-label">Índice da correta (0-3)</label>
      <input
        className="crud-input"
        type="number"
        min={0}
        max={3}
        value={v.indice_resposta}
        onChange={(e) => set("indice_resposta", Math.max(0, Math.min(3, Number(e.target.value))))}
      />

      <label className="crud-label">Explicação</label>
      <input
        className="crud-input"
        value={v.explicacao}
        onChange={(e) => set("explicacao", e.target.value)}
        placeholder="Por que essa alternativa está correta?"
      />

      <div className="crud-actions">
        <button className="crud-btn primary" disabled={submitting} type="submit">
          {submitting
            ? `Salvando...`
            : `Salvar `}
        </button>
        <button className="crud-btn outline" type="button" onClick={onCancel}>
          Cancelar
        </button>
      </div>
    </form>
  );
}

export default function QuizCRUD() {
  const [mode, setMode] = useState("grpc");
  const [items, setItems] = useState([]);
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");
  const [editing, setEditing] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const token = typeof localStorage !== "undefined" ? localStorage.getItem("token") || "" : "";

  // FUNÇÕES MOVIDAS PARA O ESCOPO DO COMPONENTE
  // Agora elas têm acesso a `mode`, `token`, `items` e `setItems`.
  async function load() {
    setErr(""); setLoading(true);
    try {
      const data = await jsonFetch(`${prefixFor(mode)}/quiz`, { token });
      const arr = Array.isArray(data) ? data : (data?.items || []);
      setItems(arr);
    } catch {
      setItems(DEMO_DATA);
      setErr("(demo) usando dados locais, não consegui buscar no backend.");
    } finally { setLoading(false); }
  }

  async function createItem(payload) {
    try {
        console.log(payload);
        const created = await jsonFetch
        (`${prefixFor(mode)}/quiz`, 
        { method: "POST", 
          body: payload, 
          token });
        return created?.id ? created : { ...payload, id: Math.max(0, ...items.map(i => i.id || 0)) + 1 };
    } catch {
        return { ...payload, id: Math.max(0, ...items.map(i => i.id || 0)) + 1 };
    }
  }

  async function updateItem(id, payload) {
    try { await jsonFetch(`${prefixFor(mode)}/quiz/${id}`, { method: "PUT", body: payload, token }); }
    catch {}
  }

  async function removeItem(id) {
    try { await jsonFetch(`${prefixFor(mode)}/quiz/${id}`, { method: "DELETE", token }); }
    catch {}
    finally { setItems(prev => prev.filter(i => i.id !== id)); }
  }

  useEffect(() => { load(); }, [mode]);

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase();
    if (!query) return items;
    return items.filter(it =>
      it.texto?.toLowerCase().includes(query) ||
      it.explicacao?.toLowerCase().includes(query) ||
      (it.alternativas || []).some(o => o?.toLowerCase().includes(query))
    );
  }, [items, q]);

  function newEmpty() {
    setEditing({ id: null, texto: "", alternativas: ["", "", "", ""], indice_resposta: 0, explicacao: "" });
  }

  async function submitForm(e) {
    e.preventDefault();
    setSubmitting(true);
    try {
      if (editing.id == null) {
        const created = await createItem(editing);
        setItems(prev => [...prev, created]);
      } else {
        await updateItem(editing.id, editing);
        setItems(prev => prev.map(it => (it.id === editing.id ? { ...editing } : it)));
      }
      setEditing(null);
    } finally { setSubmitting(false); }
  }

  return (
    <div className="crud-wrap">
      <section className="crud-card">
        <header className="crud-head">
          <div>
            <h2 className="crud-title">CRUD de Quiz</h2>
            <p className="crud-subtle">Gerencie questões: criar, editar e excluir</p>
          </div>

          {!editing && (
            <div className="crud-actions-right">
              
              <button className="crud-btn primary" onClick={newEmpty}>+ Nova questão</button>
              <button className="crud-btn" onClick={load} disabled={loading}>
                {loading
                  ? `Atualizando ...`
                  : `Atualizar`}
              </button>
            </div>
          )}
        </header>

        {!editing && (
          <div className="crud-searchbar">
            <input
              className="crud-input"
              placeholder="Buscar por texto, opção ou explicação..."
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>
        )}

        {err && <div className="crud-msg err">{err}</div>}

        {editing ? (
          <QuestionForm
            value={editing}
            onChange={setEditing}
            onSubmit={submitForm}
            onCancel={() => setEditing(null)}
            submitting={submitting}
            mode={mode}
          />
        ) : (
          <div className="crud-table-wrap">
            <table className="crud-table">
              <thead>
                <tr>
                  <th style={{ width: 64 }}>ID</th>
                  <th>Questão</th>
                  <th style={{ width: 180 }}>Correta</th>
                  <th style={{ width: 220 }}>Ações</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr><td colSpan={4} className="empty">Sem resultados.</td></tr>
                ) : (
                  filtered.map(it => (
                    <tr key={it.id}>
                      <td>{it.id}</td>
                      <td>
                        <div className="q-text">{it.texto}</div>
                        <div className="q-options">
                          {it.alternativas?.map((op, idx) => (
                            <span key={idx} className={`q-badge ${idx === it.indice_resposta ? "ok" : ""}`}>
                              {String.fromCharCode(65 + idx)}. {op}
                            </span>
                          ))}
                        </div>
                      </td>
                      <td>
                        {typeof it.indice_resposta === "number"
                          ? `Índice ${it.indice_resposta} (${String.fromCharCode(65 + it.indice_resposta)})`
                          : "-"}
                      </td>
                      <td>
                        <div className="row-actions">
                          <button className="crud-btn" onClick={() => setEditing({ ...it })}>Editar</button>
                          <button className="crud-btn danger" onClick={() => removeItem(it.id)}>Excluir</button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}

      </section>
    </div>
  );
}

// A CHAVE EXTRA NO FINAL FOI REMOVIDA