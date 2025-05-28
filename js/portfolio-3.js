// Main scroll-triggered animations
function initScrollAnimations() {
	const observerOptions = {
		threshold: 0.1,
		rootMargin: '0px 0px -50px 0px'
	};

	const observer = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('revealed');
			}
		});
	}, observerOptions);

	document.querySelectorAll('.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right').forEach(el => {
		observer.observe(el);
	});
}

// Blog post staggered animations
function initBlogPostAnimations() {
	const blogPosts = document.querySelectorAll('.blog-post');

	const blogObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate blog post elements
					const blogDate = entry.target.querySelector('.blog-date');
					const blogTitle = entry.target.querySelector('.blog-title');
					const blogExcerpt = entry.target.querySelector('.blog-excerpt');
					const readMore = entry.target.querySelector('.read-more');
					const categoryTags = entry.target.querySelectorAll('.category-tag');

					if (blogDate) {
						setTimeout(() => blogDate.classList.add('animate'), 100);
					}
					if (blogTitle) {
						setTimeout(() => blogTitle.classList.add('animate'), 200);
					}
					if (blogExcerpt) {
						setTimeout(() => blogExcerpt.classList.add('animate'), 300);
					}
					if (readMore) {
						setTimeout(() => readMore.classList.add('animate'), 400);
					}

					// Animate category tags
					categoryTags.forEach((tag, i) => {
						setTimeout(() => {
							tag.classList.add('animate');
						}, 250 + (i * 100));
					});
				}, index * 200);
			}
		});
	}, { threshold: 0.2 });

	blogPosts.forEach(post => {
		blogObserver.observe(post);
	});
}

// Blog content stagger animation
function initBlogContentStagger() {
	const contentElements = document.querySelectorAll('.blog-content-stagger');

	const contentObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 150);
			}
		});
	}, { threshold: 0.1 });

	contentElements.forEach(element => {
		contentObserver.observe(element);
	});
}

// Sidebar sections animation
function initSidebarAnimations() {
	const sidebarSections = document.querySelectorAll('.sidebar-section');

	const sidebarObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate category tags in sidebar
					const categoryTags = entry.target.querySelectorAll('.category-tag');
					categoryTags.forEach((tag, i) => {
						setTimeout(() => {
							tag.classList.add('animate');
						}, i * 50);
					});

					// Animate social links
					const socialLinks = entry.target.querySelectorAll('.social-links a');
					socialLinks.forEach((link, i) => {
						setTimeout(() => {
							link.classList.add('animate');
						}, i * 100);
					});
				}, index * 200);
			}
		});
	}, { threshold: 0.3 });

	sidebarSections.forEach(section => {
		sidebarObserver.observe(section);
	});
}

// Coming soon section animation
function initComingSoonAnimation() {
	const comingSoon = document.querySelector('.coming-soon');

	if (comingSoon) {
		const comingSoonObserver = new IntersectionObserver((entries) => {
			entries.forEach(entry => {
				if (entry.isIntersecting) {
					entry.target.classList.add('animate');
				}
			});
		}, { threshold: 0.3 });

		comingSoonObserver.observe(comingSoon);
	}
}

// Enhanced hover effects for blog posts
function initBlogHoverEffects() {
	document.querySelectorAll('.blog-post').forEach(post => {
		post.addEventListener('mouseenter', function() {
			this.style.transform = 'translateY(-10px) scale(1.02)';
			this.style.boxShadow = '0 20px 40px rgba(255, 107, 107, 0.2)';
		});

		post.addEventListener('mouseleave', function() {
			this.style.transform = 'translateY(0) scale(1)';
			this.style.boxShadow = '';
		});
	});
}

// Category tag interactive effects
function initCategoryTagEffects() {
	document.querySelectorAll('.category-tag').forEach(tag => {
		tag.addEventListener('click', function(e) {
			// Create ripple effect
			const ripple = document.createElement('span');
			const rect = this.getBoundingClientRect();
			const size = Math.max(rect.width, rect.height);
			const x = e.clientX - rect.left - size / 2;
			const y = e.clientY - rect.top - size / 2;

			ripple.style.cssText = `
				position: absolute;
				border-radius: 50%;
				background: rgba(255, 255, 255, 0.6);
				transform: scale(0);
				animation: ripple 0.6s linear;
				width: ${size}px;
				height: ${size}px;
				left: ${x}px;
				top: ${y}px;
				pointer-events: none;
			`;

			this.appendChild(ripple);

			setTimeout(() => {
				ripple.remove();
			}, 600);
		});
	});

	// Add ripple animation CSS
	if (!document.querySelector('#ripple-styles')) {
		const style = document.createElement('style');
		style.id = 'ripple-styles';
		style.textContent = `
			@keyframes ripple {
				to {
					transform: scale(4);
					opacity: 0;
				}
			}
		`;
		document.head.appendChild(style);
	}
}

// Reading progress indicator
function initReadingProgress() {
	const progressBar = document.querySelector('.reading-indicator');

	window.addEventListener('scroll', () => {
		const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
		const docHeight = document.documentElement.scrollHeight - window.innerHeight;
		const scrollPercent = (scrollTop / docHeight) * 100;

		progressBar.style.width = scrollPercent + '%';
	});
}

// Parallax scrolling effect for header
function initParallaxEffect() {
	window.addEventListener('scroll', () => {
		const scrolled = window.pageYOffset;
		const header = document.querySelector('.project-header');
		if (header) {
			header.style.transform = `translateY(${scrolled * 0.3}px)`;
		}
	});
}

// Enhanced navigation effects
function initNavigationEffects() {
	const navLinks = document.querySelectorAll('.nav-links a');
	navLinks.forEach(link => {
		link.addEventListener('mouseenter', function() {
			this.style.transform = 'translateY(-2px) scale(1.05)';
			this.style.boxShadow = '0 5px 15px rgba(255, 107, 107, 0.4)';
		});
		link.addEventListener('mouseleave', function() {
			if (!this.classList.contains('active')) {
				this.style.transform = 'translateY(0) scale(1)';
				this.style.boxShadow = '';
			}
		});
	});
}

// Blog loading simulation
function initBlogLoadingEffect() {
	const blogPosts = document.querySelectorAll('.blog-post');

	blogPosts.forEach((post, index) => {
		post.classList.add('loading');

		setTimeout(() => {
			post.classList.remove('loading');
		}, 1000 + (index * 200));
	});
}

// Smooth page loading animation
function initPageLoadAnimation() {
	document.body.style.opacity = '0';
	document.body.style.transition = 'opacity 0.5s ease';

	setTimeout(() => {
		document.body.style.opacity = '1';
	}, 100);
}

// Text typing effect for coming soon
function initTypingEffect() {
	const typingElements = document.querySelectorAll('.coming-soon p');

	typingElements.forEach((element, index) => {
		const text = element.textContent;
		element.textContent = '';
		element.style.opacity = '1';

		setTimeout(() => {
			let i = 0;
			const typeWriter = () => {
				if (i < text.length) {
					element.textContent += text.charAt(i);
					i++;
					setTimeout(typeWriter, 30);
				}
			};
			typeWriter();
		}, 1000 + (index * 500));
	});
}

// Initialize all animations when page loads
document.addEventListener('DOMContentLoaded', function() {
	initPageLoadAnimation();

	// Delay animation initialization for smooth loading
	setTimeout(() => {
		initScrollAnimations();
		initBlogPostAnimations();
		initBlogContentStagger();
		initSidebarAnimations();
		initComingSoonAnimation();
		initBlogHoverEffects();
		initCategoryTagEffects();
		initReadingProgress();
		initParallaxEffect();
		initNavigationEffects();
		// initBlogLoadingEffect(); // Uncomment for loading simulation
		// initTypingEffect(); // Uncomment for typing effect

		// Add loaded class for final touches
		document.body.classList.add('animations-loaded');
	}, 150);
});

// Add smooth scrolling for anchor links
document.addEventListener('DOMContentLoaded', function() {
	document.querySelectorAll('a[href^="#"]').forEach(anchor => {
		anchor.addEventListener('click', function (e) {
			e.preventDefault();
			const target = document.querySelector(this.getAttribute('href'));
			if (target) {
				target.scrollIntoView({
					behavior: 'smooth',
					block: 'start'
				});
			}
		});
	});
});