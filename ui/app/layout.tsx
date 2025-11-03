import type { Metadata } from "next";
import { Commissioner } from "next/font/google";
import "./globals.css";
import QueryProvider from "@/components/providers/QueryProvider";

const commissioner = Commissioner({
  variable: "--font-commissioner",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700", "800"],
});

export const metadata: Metadata = {
  title: "Todo App",
  description: "A simple todo application with Spring Boot and Next.js",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${commissioner.variable} font-commissioner antialiased`}
      >
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  );
}
