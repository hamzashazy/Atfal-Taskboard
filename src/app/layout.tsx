import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";
import Nav from "@/components/Nav";
import Toaster from "@/components/Toaster";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Atfal Taskboard",
  description: "Task management and city performance dashboard for Atfal",
  icons: {
    icon: "/atfal-logo-icon.png",
    apple: "/atfal-logo-icon.png",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${geistSans.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col font-sans">
        <Nav />
        <main className="animate-fade-up mx-auto w-full max-w-6xl flex-1 px-4 py-4">{children}</main>
        <footer className="py-6 text-center text-xs text-gray-400">
          Atfal Taskboard · one platform, every city
        </footer>
        <Toaster />
      </body>
    </html>
  );
}
