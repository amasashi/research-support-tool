import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Research Support Tool",
  description: "English paper reading assistant for Japanese researchers",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
