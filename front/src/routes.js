import React from "react";
import {
  BrowserRouter,
  Routes,
  Route,
  Navigate,
  Link,
  useLocation,
} from "react-router-dom";
import Quiz from "./Quiz";
import Login from "./Login";
import Ranking from "./Ranking";
import Home from "./Home"; 
import Cadastro from "./Cadastro";
import QuizCRUD from "./QuizCRUD";



function useToken() {
  const token =
    typeof localStorage !== "undefined" ? localStorage.getItem("token") : "";
  return token;
}

function Protected({ children }) {
  const token = useToken();
  const location = useLocation();
  if (!token) {
    
    return <Navigate to="/login" replace state={{ from: location }} />;
  }
  return children;
}


function Navbar() {
  return (
    <header
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        padding: "12px 18px",
        background: "#222",
        borderBottom: "1px solid #222",
      }}
    >
      <h1 style={{ color: "#fff", fontSize: 20, margin: 0 }}>PSPD • Quiz</h1>
      <nav style={{ display: "flex", gap: 14,  }}>
        <Link style={{ color: "#fff", textDecoration: "none" }} to="/">
          Início
        </Link>
        <Link
          style={{ color: "#fff", textDecoration: "none" }}
          to="/ranking"
        >
          Ranking
        </Link>
        <Link style={{ color: "#fff", textDecoration: "none" }} to="/login">
          Login
        </Link>
        
      </nav>
    </header>
  );
}


export default function AppRoutes() {
  return (
    <BrowserRouter>
      <Navbar />
      <div>
        <Routes>
          
          <Route path="/" element={<Home />} />

          
          <Route
            path="/quiz"
            element={
              <Protected>
                <Quiz />
              </Protected>
            }
          />

          
          <Route path="/ranking" element={<Ranking />} />

          
          <Route path="/login" element={<Login />} />
          <Route path="/cadastro" element={<Cadastro />} />
          <Route path="/quizcrud" element={<QuizCRUD />} />


          
          <Route path="*" element={<Navigate to="/" replace />} />

        </Routes>
      </div>
    </BrowserRouter>
  );
}
