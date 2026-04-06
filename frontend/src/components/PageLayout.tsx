interface Props {
  title?: string;
  showBack?: boolean;
  children: React.ReactNode;
}

export default function PageLayout({ title, showBack, children }: Props) {
  return (
    <div className="min-h-screen bg-white flex flex-col">
      {title && (
        <header className="flex items-center px-4 py-3 border-b border-si-border">
          {showBack && (
            <button onClick={() => window.history.back()} className="mr-3 text-si-gray text-xl">‹</button>
          )}
          <h1 className="text-base font-semibold text-si-dark">{title}</h1>
        </header>
      )}
      <main className="flex-1 pb-20">{children}</main>
    </div>
  );
}
