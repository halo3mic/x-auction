import Link from "next/link";

import { Button } from "@/components/ui/button";

export default function Home() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-50 to-gray-100 p-8">
      <div className="w-full max-w-md space-y-6">
        <h1 className="text-4xl font-bold text-center text-gray-800 mb-8">
          Dev Navigation
        </h1>
        <nav className="space-y-4">
          <Link href="/bid" className="block">
            <Button
              variant="default"
              className="w-full py-6 text-lg font-semibold bg-blue-600 hover:bg-blue-700 transition-colors"
            >
              Bid Page
            </Button>
          </Link>
          <Link href="/sell" className="block">
            <Button
              variant="default"
              className="w-full py-6 text-lg font-semibold bg-blue-600 hover:bg-blue-700 transition-colors"
            >
              Sell Page
            </Button>
          </Link>
        </nav>
      </div>
    </div>
  );
}
