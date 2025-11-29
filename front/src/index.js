import React from "react";
import { createRoot } from "react-dom/client";
import AppRoutes from "./routes";

// 1. Importe o CookiesProvider
import { CookiesProvider } from 'react-cookie';

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    {/* 2. Envolva o seu componente <AppRoutes /> com o provider */}
    <CookiesProvider>
      <AppRoutes />
    </CookiesProvider>
  </React.StrictMode>
);