import type { Metadata } from 'next';
import localFont from 'next/font/local';
import type { ReactNode } from 'react';
import './globals.css';

const sora = localFont({
  src: [
    { path: './fonts/Sora-600.ttf', weight: '600' },
    { path: './fonts/Sora-700.ttf', weight: '700' },
    { path: './fonts/Sora-800.ttf', weight: '800' },
  ],
  variable: '--font-sora',
  display: 'swap',
});

const jakarta = localFont({
  src: [
    { path: './fonts/PlusJakartaSans-400.ttf', weight: '400' },
    { path: './fonts/PlusJakartaSans-500.ttf', weight: '500' },
    { path: './fonts/PlusJakartaSans-600.ttf', weight: '600' },
    { path: './fonts/PlusJakartaSans-700.ttf', weight: '700' },
    { path: './fonts/PlusJakartaSans-800.ttf', weight: '800' },
  ],
  variable: '--font-jakarta',
  display: 'swap',
});

export const metadata: Metadata = {
  title: { default: 'Back-office Tara', template: '%s · Back-office Tara' },
  description: 'Outil de l’équipe Tara : dispatch, livreurs, support, finance, indicateurs.',
  robots: { index: false, follow: false },
  icons: { icon: '/marque-clair.svg' },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr" className={`${sora.variable} ${jakarta.variable}`}>
      <body className="min-h-screen bg-bg font-sans text-[15px] leading-relaxed text-text antialiased">
        {children}
      </body>
    </html>
  );
}
