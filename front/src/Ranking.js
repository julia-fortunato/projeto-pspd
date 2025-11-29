import { useMemo, useState, useEffect } from "react";
import "./Ranking.css";

/*
const DEMO_ROWS = [
  { user: "Maria", score: 980 },
  { user: "Gabriel", score: 960 },
  { user: "Ana", score: 930 },
  { user: "João", score: 890 },
  { user: "Carla", score: 870 },
  { user: "Rafa", score: 850 },
  { user: "Luiza", score: 830 },
  { user: "Pedro", score: 820 },
  { user: "Felipe", score: 810 },
  { user: "Bianca", score: 800 },
];
*/
function positionDecor(pos) {
  if (pos === 1) return { icon: "🏆", cls: "gold" };
  if (pos === 2) return { icon: "🥈", cls: "silver" };
  if (pos === 3) return { icon: "🥉", cls: "bronze" };
  return { icon: `#${pos}`, cls: "normal" };
}

function PositionBadge({ pos }) {
  const { icon, cls } = positionDecor(pos);
  return <span className={`pos-badge ${cls}`}>{icon}</span>;
}

export default function Ranking() {
  const [DEMO_ROWS, setDemoRows] = useState([]);
  const [rows, setRows] = useState([]);

  useEffect(() => {
    fetch("/grpc/ranking", {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    })
      .then((res) => {
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}`);
        }
        return res.text(); // ← mudei para .text() para testar o que o servidor devolve
      })
      .then((data) => {
        console.log("Resposta do servidor:", data);
        try {
          const json = JSON.parse(data);
          console.log("JSON parseado:", json);
          setDemoRows(json.users || []);
          const processed = json.users.map((r, i) => ({ ...r, pos: i + 1 }));
          setRows(processed);
          console.log("Linhas do ranking:", rows);
        } catch {
          console.error("Resposta não é JSON válido.");
        }
      });
  }, []);

  return (
    <div className="rk-wrap">
      <section className="rk-card">
        <header className="rk-head">
          <h2 className="rk-title">Ranking • Top 10</h2>
        </header>

        <div className="rk-table-wrap scrollable">
          <table className="rk-table compact">
            
            <colgroup>
              <col className="col-pos" />
              <col className="col-user" />
              <col className="col-score" />
            </colgroup>

            <thead>
              <tr>
                <th>Posição</th>
                <th>Usuário</th>
                <th>Pontuação</th>
              </tr>
            </thead>

            <tbody>
              {rows.map((r) => (
                <tr key={r.user}>
                  <td className="cell-pos">
                    <PositionBadge pos={r.pos} />
                  </td>
                  <td className="cell-user">
                    <span className="rk-name">{r.nome}</span>
                  </td>
                  <td className="cell-score">
                    <span className="rk-score">{r.score}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
