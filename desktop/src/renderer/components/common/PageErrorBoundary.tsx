import { Component, type ErrorInfo, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { Button } from '../ui/Button';

interface PageErrorBoundaryProps {
  children: ReactNode;
}

interface PageErrorBoundaryState {
  hasError: boolean;
  message: string;
  componentStack: string;
}

export class PageErrorBoundary extends Component<
  PageErrorBoundaryProps,
  PageErrorBoundaryState
> {
  state: PageErrorBoundaryState = {
    hasError: false,
    message: '',
    componentStack: '',
  };

  static getDerivedStateFromError(error: Error): PageErrorBoundaryState {
    return {
      hasError: true,
      message: error.message || 'Unexpected render error',
      componentStack: '',
    };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.setState({ componentStack: info.componentStack || '' });
    console.error('Page render error:', error, info);
  }

  componentDidUpdate(prevProps: PageErrorBoundaryProps) {
    if (this.state.hasError && prevProps.children !== this.props.children) {
      this.resetError();
    }
  }

  resetError = () => {
    this.setState({
      hasError: false,
      message: '',
      componentStack: '',
    });
  };

  render() {
    if (this.state.hasError) {
      return (
        <div className="rounded-lg border border-red-500/20 bg-red-500/5 p-6">
          <h2 className="text-base font-semibold text-red-400">
            This page failed to render
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">{this.state.message}</p>
          {this.state.componentStack && (
            <pre className="mt-3 max-h-40 overflow-auto rounded-md border border-border bg-background p-2 text-xs text-muted-foreground whitespace-pre-wrap">
              {this.state.componentStack}
            </pre>
          )}
          <div className="mt-4 flex items-center gap-2">
            <Link
              to="/"
              onClick={this.resetError}
              className="inline-flex h-9 items-center rounded-md border border-input bg-background px-3 text-sm hover:bg-accent"
            >
              Back to Dashboard
            </Link>
            <Button
              variant="secondary"
              onClick={this.resetError}
            >
              Try again
            </Button>
            <Button
              variant="secondary"
              onClick={() => window.location.reload()}
            >
              Reload page
            </Button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
